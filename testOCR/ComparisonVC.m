//
//                                        _              __     ______
//    ___ ___  _ __ ___  _ __   __ _ _ __(_)___  ___  _ _\ \   / / ___|
//   / __/ _ \| '_ ` _ \| '_ \ / _` | '__| / __|/ _ \| '_ \ \ / / |
//  | (_| (_) | | | | | | |_) | (_| | |  | \__ \ (_) | | | \ V /| |___
//   \___\___/|_| |_| |_| .__/ \__,_|_|  |_|___/\___/|_| |_|\_/  \____|
//                      |_|
//
//  comparisonVC.m
//  testOCR
//  this VC is for selecting a pre-processed CSV file with all EXP data.
//   to be used to compare with OCR generated results
//
//  Created by Dave Scruton on 2/1/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "ComparisonVC.h"

@interface ComparisonVC ()

@end

@implementation ComparisonVC

//=============Comparison VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];

    et = [[EXPTable alloc] init];
    et.delegate = self;
    [et setTableName : @"EXP_Comparison"]; //Special table name!

    act = [[ActivityTable alloc] init];
    
    vv  = [Vendors sharedInstance];

    smartp = [[smartProducts alloc] init];

    
    csvEntries  = [[NSArray alloc] init];
    pamHeaders  = [[NSArray alloc] init];
    pamKeywords = [[NSArray alloc] init];
    columnKeys  = [[NSMutableArray alloc] init];

    //Month-by-month array of EXPStats...
    monthlyStats  = [[NSMutableArray alloc] init];
    
    //[self stripCommasFromQuotedStrings:@"abc\"duh ,guk\"de,fg"];
    [self loadConstants]; //populates pamHeaders / pamKeywords arrays
    return self;
}


//=============Comparison VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    _table.delegate   = self;
    _table.dataSource = self;
    // Do any additional setup after loading the view.
    // Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, (int)csz.width, (int)csz.height)];
    [self.view addSubview:spv];

}

//=============Batch VC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self getComparisonFolderList];
} //end viewDidAppear


//=============Comparison VC=====================================================
-(void) dismiss
{
    et.parentUp = FALSE; //2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}


//=============Comparison VC=====================================================
- (IBAction)backSelect:(id)sender {
    [self dismiss];
}


//=============Comparison VC=====================================================
-(void) getComparisonFolderList
{
    [spv start:@"Get File List"];
    AppDelegate *cappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    comparisonFolderPath = [NSString stringWithFormat:@"%@",cappDelegate.settings.comparisonFolder];
    [dbt getFolderList:comparisonFolderPath];
} //end getComparisonFolderList


//=============Comparison VC=====================================================
// User selected something, load it!
-(void) loadCSV : (int) row
{
    DBFILESMetadata *entry = csvEntries[row];
    comparisonFilePath = [NSString stringWithFormat:@"/%@/%@",comparisonFolderPath,entry.name];
    NSLog(@" load csv %@",comparisonFilePath);
    [dbt downloadCSV : comparisonFilePath :@"NoVendor"];

}


//=============Comparison VC=====================================================
-(void) loadConstants
{
    pamHeaders  = @[  //Human-readable CSV headers from Excel
                   @"category", @"month", @"item", @"quantity",
                   @"unit of measure", @"bulk/ individual pack", @"vendor name", @"total price",
                   @"price/ uom", @"processed", @"local (l)", @"invoice date",
                   @"line #"
                   ];
    pamKeywords = @[  //matching PARSE column names
                    PInv_Category_key,PInv_Month_key,PInv_ProductName_key,PInv_Quantity_key,
                    PInv_UOM_key,PInv_Bulk_or_Individual_key,PInv_Vendor_key,PInv_TotalPrice_key,
                    PInv_PricePerUOM_key,PInv_Processed_key,PInv_Local_key,PInv_Date_key,
                    PInv_LineNumber_key
                   ];


} //end loadConstants


//=============Comparison VC=====================================================
//Can't break up a CSV string right if it has commas inside quoted names (like vendor!)
-(NSString *) stripCommasFromQuotedStrings : (NSString*) s
{
    NSString *result = @"";
    NSRange theRange;
    BOOL inQuotes = FALSE;
    for ( NSInteger i = 0; i < [s length]; i++) {
        theRange.location = i;
        theRange.length   = 1;
        NSString* nextChar = [s substringWithRange:theRange];
        if ([nextChar isEqualToString:@"\""]) //double quotes? toggle quotes flag
        {
            inQuotes = !inQuotes;
        }
        else if ([nextChar isEqualToString:@","]) //comma? don't append if inside quotes!
        {
            if (!inQuotes) result = [result stringByAppendingString:nextChar];
        } //Not a quote or comma..... just append
        else result = [result stringByAppendingString:nextChar];
    } //end for i
    return result;
} //end stripCommasFromQuotedStrings

// Sample Lines from CSV:
//CATEGORY,Month,Item,Quantity,Unit Of Measure,BULK/ INDIVIDUAL PACK,Vendor Name, Total Price ,PRICE/ UOM,PROCESSED ,Local (L),Invoice Date,Line #,,
//  PROTEIN,01-JUL,Ground Beef,80,lb,,"Hawaii Beef Producers, LLC", $236.80 ,$2.96,UNPROCESSED,Yes,07/03/2018,1,,

//=============Comparison VC=====================================================
// BUG: this record fux it up:
//PROTEIN,01-JUL,Ground Beef,80,lb,,"Hawaii Beef Producers, LLC", $236.80 ,$2.96,UNPROCESSED,Yes,07/03/2018,1,,
// NOTICE extra comma inside quotes!
-(void) processCSV : (NSString *)s
{
    NSLog(@" processing... get hdr info first:");
    //First check column ordering...
    NSArray  *csvItems = [s componentsSeparatedByString:@"\n"]; //Break up file into lines
    if (csvItems.count < 2)
    {
        NSLog(@" ERROR: no data in CSV File!");
        return;
    }
    [spv start:@"Processing CSV..."];

    [columnKeys removeAllObjects]; //Clear columns...
    NSString *legend      = csvItems[0];
    NSArray  *legendItems = [legend componentsSeparatedByString:@","]; //Break up legend...
    for (NSString *nextHeader in legendItems)
    {
        NSString *hhh = [nextHeader stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSUInteger wherezit = [pamHeaders indexOfObject:hhh.lowercaseString];
        if (wherezit != NSNotFound)
        {
            [columnKeys addObject: [pamKeywords objectAtIndex:wherezit]];
        }
        else if (hhh.length > 1){
            NSLog(@" ERROR: unmatched CSV header title %@",nextHeader);
            return;
        }
    }
    //Work strings...
    BOOL firstRecord = TRUE;
    writeCount = okCount = errCount = 0;
    loadCount  = (int)csvItems.count;
    [et clear];
    for (NSString *nextLine in csvItems)
    {
        if (!firstRecord) //Skip 1st record...
        {
            NSString* noQuotedCommas =  [self stripCommasFromQuotedStrings:nextLine];
            NSArray  *nlItems      = [noQuotedCommas componentsSeparatedByString:@","]; //Break up line...
            NSMutableArray *fields = [[NSMutableArray alloc] init];
            NSMutableArray *values = [[NSMutableArray alloc] init];
            NSDate *idate          = [NSDate date];
            for (int i=0;i<nlItems.count;i++) //Go thru fields...
            {
                if (i >= pamKeywords.count) break; //Out of bounds or extra args on line? skip!
                NSString *nextField = nlItems[i];
                NSString *nextPamKw = pamKeywords[i];
                if ([nextPamKw isEqualToString:PInv_Date_key])
                { //date format: 07/03/2018
                    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"MM/dd/yyyy"];
                    idate = [formatter dateFromString:nextField]; //Unpack date
                }
                else{
                    [fields addObject:nextPamKw];
                    [values addObject:nextField];
                }
            } //end for i
            if (values.count > 2) //Did we get something?
            {
                //OK ready to write!
                if (writeCount % 100 == 0) NSLog(@" write %d/%d [%@]",writeCount,loadCount,values[2]);
                [et addRecordFromArrays : idate :  fields : values];
                writeCount++;
            }
        } //end !first...
        firstRecord = FALSE;
    } //end for loop
    NSLog(@" writing %d records",writeCount);
    [spv start:@"Save CSVs -> Parse..."];

    //CLUGE: TEST ONLY [et saveEXPOs];
    [self getStats];


} //end processCSV


//=============Comparison VC=====================================================
-(void) getStats
{
    int rcount = (int)et.expos.count;  //expos record count
    
    [monthlyStats removeAllObjects];
    
    for (int month = 1; month<=2;month++) //Loop over the year
    {
        EXPStats *estats   = [[EXPStats alloc] init];
        NSString *monthStr = [estats getMonthName:month];
        NSLog(@"%@===========================================",monthStr );
        [estats clear]; //Clear stats...
        //loop over allll exp objects
        for (int i=0;i<rcount;i++)
        {
            NSString *rmonth = [et getMonth:i];
            if ([rmonth isEqualToString:monthStr]) //Match?
            {
                NSString *vendor   = [et getVendor:i];
                NSString *category = [et getCategory:i];
                category = [category stringByReplacingOccurrencesOfString:@" " withString:@""]; //Trim!
                NSUInteger catIndex = [estats getCategoryIndex : category];
                //asdf
                if (catIndex == NSNotFound) //Wups!
                {
                    NSLog(@" cat [%@] not found!",category);
                }
                int  vindex     = [vv getVendorIndex:vendor]; //this is dimensioned by all possible vendors!
//                if ([category.lowercaseString containsString:@"protein"])
//                {
//                    NSLog(@" protein %d",i);
//                }
                int  amount     = [et getAmount:i];
                BOOL locFlag    = [et getLocal:i];
                BOOL proFlag    = [et getProcessed:i];
                
                [estats addAmount :vindex :amount ];
                if (locFlag)
                {
                    [estats addLAmount :vindex :amount ];
                }
                if (proFlag)
                {
                    [estats addPAmount :vindex :amount ];
                }
                
                if ([estats isFoodItem : category])
                {
                    [estats addFAmount : vindex : amount];
                }
                
                //Update category info too
                [estats addCatAmount :vindex :(int)catIndex :amount : proFlag];
            } //end if rmonth
        }    //end for i
        [estats dump];
        [monthlyStats addObject:estats];
    }       //end for month
    
    NSLog(@" got allll stats ");

} //end getStats

//=============Comparison VC=====================================================
-(void) checkForFinish
{
    if (writeCount == 0) return;
    if ((okCount+errCount) == writeCount)
    {
        [act saveActivityToParse:@"Wrote Comparison EXP records from:" : comparisonFilePath];
        NSLog(@"OK, wrote all records %d OK vs %d errs",okCount,errCount);
        [spv stop];

    }
}




#pragma mark - UITableViewDelegate


//=============<UITableViewDelegate>=====================================================
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    //cell.bottomLabel.text = adata;
    NSString *tstr = @"Empty";
    
    if (row <= csvEntries.count)
    {
        DBFILESMetadata *entry = csvEntries[row];
        tstr = entry.name;
    }
    cell.textLabel.text = tstr;

    return cell;
} //end cellForRowAtIndexPath


//=============<UITableViewDelegate>=====================================================
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return csvEntries.count;
}

//=============<UITableViewDelegate>=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

//=============OCR MainVC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [spv start:@"Load CSV..."];
    [self loadCSV : (int)indexPath.row];
}


#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
- (void)didGetFolderList : (NSArray *)entries
{
    NSLog(@" ok got fodler");
    [spv stop];
    csvEntries = entries; //Store results locally, list of dropbox entries
    [_table reloadData];
}

//===========<DropboxToolDelegate>================================================
- (void)didDownloadCSVFile : (NSString *)vendor : (NSString *)result
{
    NSLog(@" annnd result is %@",result);
    [spv stop];
    [self processCSV:result];

}


//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingCSV : (NSString *)s
{
    NSLog(@" errorDownloadingCSV %@",s);

}

#pragma mark - EXPTableDelegate

//============<EXPTableDelegate>====================================================
- (void)didSaveEXPOs
{
    NSLog(@" didsaveexpos");
    [spv stop];

}

//============<EXPTableDelegate>====================================================
- (void)errorSavingEXPOs : (NSString *)err
{
    NSLog(@" errorSavingEXPOs %@",err);
    [spv stop];

}

@end
