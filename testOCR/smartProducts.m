//
//                            _   ____                _            _
//   ___ _ __ ___   __ _ _ __| |_|  _ \ _ __ ___   __| |_   _  ___| |_ ___
//  / __| '_ ` _ \ / _` | '__| __| |_) | '__/ _ \ / _` | | | |/ __| __/ __|
//  \__ \ | | | | | (_| | |  | |_|  __/| | | (_) | (_| | |_| | (__| |_\__ \
//  |___/_| |_| |_|\__,_|_|   \__|_|   |_|  \___/ \__,_|\__,_|\___|\__|___/
//
//  smartProducts.m
//  testOCR
//
//  Created by Dave Scruton on 12/12/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  12/31 add typos
//  1/10  add analyze, get rid of old analyze stuff...
//  2/4   remove _analyzedShortDateString
//  2/5   redid q / p / a match check again
//  2/14  add int/float quantity support
//  3/4   broke out keywords, typos etc read from parse,
//          needed to make them re-entrant for large tables
//          removed wilds / notwilds
//  3/13  analyze: bail on empty product name
//  3/15  add keywordsNo1stChar dictionary
//        add even price/amount comparison check (bad math)
//        made zero quantity a major error (not warning)
//  3/22  add T default for intQuantity, assume zero quantity = 1
//         also assume 3-digit prices are errors missing decimal point
//  6/11  add doubleKeywords
// NOTE:  for double keywords, "green beans" -> "produce" should work for:
//              green beans/beans green/reen beans/eans green
//  6/14  add nonProducts table to sashido
//  7/15  add more processed terms, pulled cocktail from kws
//  7/22  add processedProduceKeywords table to DB
//  7/26  Removed all canned keyword names (beverageNames, etc). use DB exclusively
//          had to move some flag setting down in the code, see date marks
//  7/30  add udKeywords;
//  8/7   add invoiceKeywords
//  2/25/20 comment out NSLogs
//  3/2/20 remove redundant whitespace from fullProductName in analyze
//  3/13   add error handling in loadDoubleKeywordsFromParse and loadUDKeywordsFromParse
//        for badMath / zeroQuantity errors, check if price is even divisor of amount.
//          if so, set quantity to the computed integer value amount / price. 2 cents tolerance
//  3/20  add getGordonCaseCount, gets first number it sees in Description col
//  4/5   invert negative quantity in analyze
#import "smartProducts.h"

@implementation smartProducts


//=============(smartProducts)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        [self loadTables];
        occ         = [OCRCategories sharedInstance];
        typos       =  [[NSMutableArray alloc] init];
        fixed       =  [[NSMutableArray alloc] init];
        splits      =  [[NSMutableArray alloc] init];
        joined      =  [[NSMutableArray alloc] init];
        keywords    =  [[NSMutableDictionary alloc] init];
        dKeywords   =  [[NSMutableDictionary alloc] init];
        keywordCats =  [[NSMutableDictionary alloc] init];  //3/13/20 new info
        keywordCatsNo1stChar =  [[NSMutableDictionary alloc] init];  //3/13/20 new info

        nonProducts =  [[NSMutableArray alloc] init];   //6/14
        invoiceKeywords =  [[NSMutableArray alloc] init];   //8/7
        ppKeywords  =  [[NSMutableArray alloc] init];   //7/22
        udKeywords  =  [[NSMutableArray alloc] init];   //7/30
        
        keywordsNo1stChar  =  [[NSMutableDictionary alloc] init]; //3/15
        dKeywordsNo1stChar =  [[NSMutableDictionary alloc] init]; //3/15
        //3/13/20 new info
        dKeywordCatsNo1stChar =  [[NSMutableDictionary alloc] init]; //3/15
        dKeywordCats          =  [[NSMutableDictionary alloc] init]; //3/15
        didInitAlready = FALSE;
        _intQuantity   = TRUE; //DHS 3/22 assume int quantities
        [self loadRulesTextFile : @"splits" : FALSE : splits : joined];
        [self loadRulesTextFile : @"typos"  : TRUE :  typos  : fixed];

        [self loadKeywordsFromParse : 0];
        [self loadDoubleKeywordsFromParse : 0];
        [self loadTyposFromParse : 0];
        [self loadSplitsFromParse : 0];
        [self loadInvoiceKeywordsFromParse:0];
        [self loadNonProductsFromParse:0];
        //DHS 3/13 pull [self loadPPKeywordsFromParse:0];
        //DHS 3/13 pull [self loadUDKeywordsFromParse:0];
    }
    return self;
}

//=============(smartProducts)=====================================================
-(int) getKeywordCount : (NSString*)category
{
    if ([category.lowercaseString isEqualToString:@"beverage"])      return (int)beverageNames.count;
    else if ([category.lowercaseString isEqualToString:@"bread"])    return (int)breadNames.count;
    else if ([category.lowercaseString isEqualToString:@"dairy"])    return (int)dairyNames.count;
    else if ([category.lowercaseString isEqualToString:@"drygoods"]) return (int)dryGoodsNames.count;
    else if ([category.lowercaseString isEqualToString:@"misc"])     return (int)miscNames.count;
    else if ([category.lowercaseString isEqualToString:@"protein"])  return (int)proteinNames.count;
    else if ([category.lowercaseString isEqualToString:@"produce"])  return (int)produceNames.count;
    else if ([category.lowercaseString isEqualToString:@"supplies"]) return (int)suppliesNames.count;

    return 0;
}

//=============(smartProducts)=====================================================
// Provides external access to the built-in categories
-(NSString*) getKeyword : (NSString*)category : (int) index
{
    NSString *result = @"";
    if (index < 0) return result;
    if ([category.lowercaseString isEqualToString:@"beverage"])
    {
        if (index < beverageNames.count) return beverageNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"bread"])
    {
        if (index < breadNames.count) return breadNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"dairy"])
    {
        if (index < dairyNames.count) return dairyNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"drygoods"])
    {
        if (index < dryGoodsNames.count) return dryGoodsNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"misc"])
    {
        if (index < miscNames.count) return miscNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"protein"])
    {
        if (index < proteinNames.count) return proteinNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"produce"])
    {
        if (index < produceNames.count) return produceNames[index];
    }
    else if ([category.lowercaseString isEqualToString:@"supplies"])
    {
        if (index < suppliesNames.count) return suppliesNames[index];
    }
    return result;
} //end getKeyword


//=============(smartProducts)=====================================================
// DHS 3/15 check for even prices (no pennies)
-(BOOL) hasZeroCents : (float) fnum
{
    float ftest = (float)( (int)fnum);
    return (ftest == fnum);
}


//=============(smartProducts)=====================================================
//STUBBED FOR NOW, use DB
-(void) loadTables
{
    
    categories = @[  //CANNED stuff that never is a product
                    @"beverage",
                    @"bread",
                    @"dairy",
                    @"drygoods",
                    @"misc",
                    @"protein",
                    @"produce",
                    @"snacks",
                    @"supplies"
                    ];

}

//=============(smartProducts)=====================================================
-(void) clearOutputs
{
    _analyzedCategory = @"";
    _analyzedUOM = @"";
    _analyzedBulkOrIndividual = @"";
    _analyzedQuantity = @"";
    _analyzedPricePerUOM = @"";
    _analyzedPrice = @"";
    _analyzedProcessed = @"";
    _analyzedLocal = @"";
    _analyzedLineNumber  = @"";
    _analyzedProductName = @"";
    _analyzedVendor = @"";
    _analyzedAmount = @"";
    _analyzedDateString = @"";

}


//=============(smartProducts)=====================================================
// Writes out new keyword, typos, and splits tables to Parse for invoice
//  product analysis.  Assumes these tables are EMPTY. Does not delete anything.
-(void) saveKeywordsAndTyposToParse
{
    if (didInitAlready) return;
    NSLog(@" save Keywords and Typos to Parse");
    [self saveBuiltinKeywordsToParse];
    [self saveTyposAndSplitsToParse];
    didInitAlready = TRUE;

}

//=============(smartProducts)=====================================================
// NOTE: will add multiple copies if used multiple times!
-(void) saveBuiltinKeywordsToParse
{
    //Loop over all types, then over all kw's...
    int recCount = 0;
    for (NSString *cat in categories)
    {
        for (int i=0;i<[self getKeywordCount:cat];i++) //Get each kw in category
        {
            PFObject *kwRecord = [PFObject objectWithClassName:@"Keywords"];
            kwRecord[PInv_Category_key] = cat;
            NSString *keyword = [self getKeyword:cat :i];
            kwRecord[PInv_Name_key] = keyword;
            //NSLog(@" ...write [%@]%@",cat,keyword);
            [kwRecord saveEventually]; //Just save right off, don't care about return
            recCount++;
        }
    }
    NSLog(@" ...saved %d records",recCount);
} //end saveBuiltinKeywordsToParse

//=============(smartProducts)=====================================================
// NOTE: will add multiple copies if used multiple times! 
-(void) saveTyposAndSplitsToParse
{
    NSLog(@" save %d typos...",(int)typos.count);
    for (int i=0;i<(int)typos.count;i++) //Get each kw in category
    {
        PFObject *typoRecord = [PFObject objectWithClassName:@"Typos"];
        typoRecord[PInv_Typo_key]  = typos[i];
        typoRecord[PInv_Fixed_key] = fixed[i];
        [typoRecord saveEventually];
    }
    NSLog(@" save %d splits...",(int)splits.count);
    for (int i=0;i<(int)splits.count;i++) //Get each kw in category
    {
        PFObject *splitRecord = [PFObject objectWithClassName:@"Splits"];
        splitRecord[PInv_Split_key]  = splits[i];
        splitRecord[PInv_Joined_key] = joined[i];
        [splitRecord saveEventually];
    }
} //end saveTyposToParse

//=============(smartProducts)=====================================================
// 3/4 broke each table out to its own re-entrant method for loading more than 100 items!
// 3/13 add processed column handler
-(void) loadKeywordsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"Keywords"];
    query.skip = skip;
    if (skip == 0)
    {
        [keywords              removeAllObjects];
        [keywordsNo1stChar     removeAllObjects];
        [keywordCats           removeAllObjects];
        [keywordCatsNo1stChar  removeAllObjects];
    }

    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                NSString *keyword = pfo[PInv_Name_key];
                NSString *cat     = pfo[PInv_Category_key];   //3/13/20
                NSString *procyn  = pfo[PInv_Processed_key];  //3/13/20
                NSArray *kItems = [keyword componentsSeparatedByString:@" "]; //Separate words
                if (kItems.count > 1) //3/13 Found more than 1 word? ERROR
                {
                    NSLog(@" ERROR: multiple words in single kw!: [%@]",keyword);
                }
                [self->keywords setObject:cat forKey:keyword];
                // 3/13 add processed boolean
                NSNumber *nn = [NSNumber numberWithBool:
                                [procyn.lowercaseString isEqualToString:@"y"] ];
                [self->keywordCats setObject:nn forKey:keyword];  //3/13/20 new
                // 3/15 partial keywords, first char missing
                NSString *catkey = [NSString stringWithFormat:@"%@:%@",cat,keyword];
                // For HFM invoices mostly: 1st letter is often missing from kws!
                NSString *keyNo1sChar = [keyword substringFromIndex:1];
                [self->keywordsNo1stChar setObject:catkey    forKey:keyNo1sChar];
                [self->keywordCatsNo1stChar setObject:catkey forKey:keyNo1sChar]; //3/13/20 new
            }
            if (objects.count == 100) [self loadKeywordsFromParse:skip+100];
            //else NSLog(@" ...found %d keywords %d nofirstchars",
            //           (int)self->keywords.count,(int)self->keywordsNo1stChar.count);
        }
    }];
} //end loadKeywordsFromParse

//=============(smartProducts)=====================================================
// 7/22 processed produce kws, recursive
-(void) loadPPKeywordsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"processedProduceKeywords"];
    query.skip = skip;
    if (skip == 0)
    {
        [ppKeywords          removeAllObjects];
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                NSString *keyword = pfo[PInv_Name_key];
                [self->ppKeywords addObject:keyword];
            }
            if (objects.count == 100) [self loadPPKeywordsFromParse:skip+100];
            //else
            //    NSLog(@" ...got %d PPkeywords", (int)self->ppKeywords.count);
        }
    }];
} //end loadPPKeywordsFromParse

//=============(smartProducts)=====================================================
// 7/30 unprocessed drygoods kws, recursive
-(void) loadUDKeywordsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"unprocessedDrygoodsKeywords"];
    query.skip = skip;
    if (skip == 0)
    {
        [udKeywords          removeAllObjects];
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                NSString *keyword = pfo[PInv_Name_key];
                NSArray *kItems = [keyword componentsSeparatedByString:@" "]; //Separate words
                if (kItems.count > 1) //3/13 Found more than 1 word? ERROR
                {
                    NSLog(@" ERROR: multiple words in single UD kw!: [%@]",keyword);
                }
                [self->udKeywords addObject:keyword];
            }
            if (objects.count == 100) [self loadUDKeywordsFromParse:skip+100];
            //else
            //    NSLog(@" ...got %d UDkeywords", (int)self->udKeywords.count);
        }
    }];
} //end loadUDKeywordsFromParse

//=============(smartProducts)=====================================================
// 6/11 double keywords (green beans, pinto beans, etc)
// 3/13/20 CRASH, nil kw!
-(void) loadDoubleKeywordsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"DoubleKeywords"];
    query.skip = skip;
    if (skip == 0)
    {
        [dKeywords             removeAllObjects];
        [dKeywordsNo1stChar    removeAllObjects];
        //3/13/20 new data
        [dKeywordCats          removeAllObjects];
        [dKeywordCatsNo1stChar removeAllObjects];
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            //int ocount = (int)objects.count;
            for (PFObject *pfo in objects)
            {
                NSString *keyword = pfo[PInv_Name_key];
                NSString *cat     = pfo[PInv_Category_key];
                NSString *procyn  = pfo[PInv_Processed_key]; //3/13/20 add processed boolean
                NSNumber *nn      = [NSNumber numberWithBool:
                                     [procyn.lowercaseString isEqualToString:@"y"] ];
                //Now reverse the two words...
                NSArray *kItems = [keyword componentsSeparatedByString:@" "]; //Separate words
                if (keyword == nil || cat == nil)
                    NSLog(@" ERROR: nil double kw or cat!");
                NSString *keywordReversed = keyword; //3/13: crash fix? start w/ something!
                if (kItems.count == 2) //Found 2 words? Reverse-em!
                {
                    keywordReversed = [NSString stringWithFormat:@"%@ %@",kItems[1],kItems[0]];
                }
                else if (kItems.count == 1) //3/13 more error handling
                {
                    NSLog(@" ERROR: bad kw count in double kws!: [%@]",keyword);
                }
                [self->dKeywords setObject:cat forKey:keyword];
                [self->dKeywords setObject:cat forKey:keywordReversed];
                [self->dKeywordCats setObject:nn forKey:keyword];
                [self->dKeywordCats setObject:nn forKey:keywordReversed];
                // 3/15 partial keywords, first char missing
                [self->dKeywordsNo1stChar setObject:cat forKey:[keyword substringFromIndex:1]];
                [self->dKeywordsNo1stChar setObject:cat forKey:[keywordReversed substringFromIndex:1]];
                //3/13/20 add categories...
                [self->dKeywordCatsNo1stChar setObject:nn forKey:[keyword substringFromIndex:1]];
                [self->dKeywordCatsNo1stChar setObject:nn forKey:[keywordReversed substringFromIndex:1]];
            }
            if (objects.count == 100) [self loadDoubleKeywordsFromParse:skip+100];
            //else NSLog(@" ...got %d doublekeywords %d nofirstchars (%d records read from DB)",
            //                       (int)self->dKeywords.count,(int)self->dKeywordsNo1stChar.count, ocount);
        }
    }];
} //end loadDoubleKeywordsFromParse

//=============(smartProducts)=====================================================
// 6/14 read one and two-word nonproduct descriptions from db
-(void) loadNonProductsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"NonProducts"];
    query.skip = skip;
    if (skip == 0)
    {
        [nonProducts removeAllObjects];
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                NSString *nextNonProduct = pfo[PInv_Name_key];
                [self->nonProducts addObject:nextNonProduct];
            }
            if (objects.count == 100) [self loadNonProductsFromParse:skip+100];
            //else NSLog(@" ...found %d nonProducts", (int)self->nonProducts.count);
        }
    }];
} //end loadNonProductsFromParse

//=============(smartProducts)=====================================================
// 6/14 read one and two-word nonproduct descriptions from db
-(void) loadInvoiceKeywordsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"InvoiceKeywords"];
    query.skip = skip;
    if (skip == 0)
    {
        [invoiceKeywords removeAllObjects];
    }
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                NSString *nextInvoiceKeyword = pfo[PInv_Name_key];
                [self->invoiceKeywords addObject:nextInvoiceKeyword];
            }
            if (objects.count == 100) [self loadInvoiceKeywordsFromParse:skip+100];
            //else NSLog(@" ...found %d ikws", (int)self->invoiceKeywords.count);
        }
    }];
} //end loadInvoiceKeywordsFromParse


//=============(smartProducts)=====================================================
// 3/4 broke each table out to its own re-entrant method for loading more than 100 items!
-(void) loadTyposFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"Typos"];
    query.skip = skip;
    if (skip == 0)
    {
        [typos removeAllObjects];
        [fixed removeAllObjects];
    }
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                [self->typos addObject:pfo[PInv_Typo_key]];
                [self->fixed addObject:pfo[PInv_Fixed_key]];
            }
            if (objects.count == 100) [self loadTyposFromParse:skip+100];
            //else NSLog(@" ...found %d typos",(int)self->typos.count);
        }
    }];
} //end loadTyposFromParse

//=============(smartProducts)=====================================================
// 3/4 broke each table out to its own re-entrant method for loading more than 100 items!
-(void) loadSplitsFromParse : (int) skip
{
    PFQuery *query = [PFQuery queryWithClassName:@"Splits"];
    query.skip = skip;
    if (skip == 0)
    {
        [splits removeAllObjects];
        [joined removeAllObjects];
    }
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (PFObject *pfo in objects)
            {
                [self->splits addObject:pfo[PInv_Split_key]];
                [self->joined addObject:pfo[PInv_Joined_key]];
            }
            if (objects.count == 100) [self loadSplitsFromParse:skip+100];
            //else NSLog(@" ...found %d splits",(int)self->splits.count);
        }
    }];
} //end loadSplitsFromParse


//=============(smartProducts)=====================================================
-(void) clear
{
    fullProductName = @"";
    vendor = @"";
    _invoiceDate = [NSDate date];
    _invoiceDateString = @"";
    uom = @"";
    lineNumber = 0;
}

//=============(smartProducts)=====================================================
-(void) addDate : (NSDate*)ndate
{
    _invoiceDate = ndate;
}

//=============(smartProducts)=====================================================
-(void) addLineNumber : (int)n
{
    lineNumber = n;
}

//=============(smartProducts)=====================================================
-(void) addAmount : (NSString*)s
{
    amount = s; //String
}

//=============(smartProducts)=====================================================
-(void) addPrice : (NSString*)s
{
    price = s; //String
}

//=============(smartProducts)=====================================================
-(void) addUOM : (NSString*)s
{
    NSString* cs = [self removePunctuationFromString : s];
    uom          = cs;  
}

//=============(smartProducts)=====================================================
// Inputs to analyzer: keep inputs private!
-(void) addProductName : (NSString*)pname;
{
    fullProductName = pname;
}


//=============(smartProducts)=====================================================
-(void) addVendor : (NSString*)vname;
{
    vendor = vname;
}

//=============(smartProducts)=====================================================
-(void) addQuantity:(NSString *)qstr
{
    quantity = qstr;
}


//=============(smartProducts)=====================================================
-(NSString*) getErrDescription : (int) aerr
{
    NSString *result = @"Bad Errcode";
    switch(aerr)
    {
        case ANALYZER_BAD_PRICE_COLUMNS: result = @"Zero QPA Columns";
            break;
        case ANALYZER_MATH_ERROR:        result = @"Math Err";
            break;
        case ANALYZER_NO_PRODUCT_FOUND:  result =[NSString stringWithFormat:@"No Product Found (%@)",fullProductName];
            break;
        case ANALYZER_ZERO_AMOUNT:       result = @"Zero Amount";
            break;
        case ANALYZER_ZERO_PRICE:        result = @"Zero Price";
            break;
        case ANALYZER_ZERO_QUANTITY:     result = @"Zero Quantity";
            break;
        case ANALYZER_BAD_MATH:          result = @"Bad Math";
            break;
        case ANALYZER_NONPRODUCT:        result = @"Non-Product";
            break;
    }

    return result;
} //end getErrDescription

//=============(smartProducts)=====================================================
-(NSString*) getMinorErrorString
{
    return [self getErrDescription : _minorError];
}

//=============(smartProducts)=====================================================
-(NSString*) getMajorErrorString
{
    return [self getErrDescription : _majorError];
}

//=============(smartProducts)=====================================================
-(int) getGordonCaseCount : (NSString*) s
{
    NSArray *pItems = [s componentsSeparatedByString:@" "]; //Separate words
    if (pItems.count == 0) return 0;
    NSString *s0 = pItems[0];
    int testInt = s0.intValue;
    //NSLog(@" gordon item %@ first [%@] val %d",s,pItems[0],testInt);
    return testInt;
}

//=============(smartProducts)=====================================================
// Does ALL analyzing...non-zero return value means FAIL: Don't ADD!
//  VERY long method, could benefit from breaking up into smaller chunks
-(int) analyze
{
    [self clearOutputs]; //Get rid of residue from last pass...
    _analyzeOK  = FALSE;
    processed   = FALSE;
    local       = FALSE;
    bulk        = FALSE;
    _nonProduct = FALSE;
    int aerror  = 0;
    _majorError = 0;
    //3/13 Bail on empty product:
    if ([fullProductName isEqualToString:@""]) 
    {
        _nonProduct = TRUE;
        return ANALYZER_NONPRODUCT;
    }
    
    _lastProductName = fullProductName; //3/31/20
    
    //3/19/20 test of just GORDON:
    if ([vendor.lowercaseString isEqualToString:@"gordon"] )
    {
        int cc = [self getGordonCaseCount:fullProductName];
    }
    

    //3/2/20 Remove redundant whitespace, this makes two-word searches easier...
    //       there is NO NSString function that does this, WTF???
    while ([fullProductName rangeOfString:@"  "].location != NSNotFound) {
        fullProductName = [fullProductName stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    
    // 8/7 Check for invoice-related keywords first...
    for (NSString *ikw in invoiceKeywords) //6/14 mutableArray, loaded from parse now
    {
        if ([fullProductName.lowercaseString containsString:ikw])
        {
            _nonProduct = TRUE;
            //NSLog(@" ...invoice keyword (nonproduct) %@",fullProductName);
            return ANALYZER_NONPRODUCT;
        }
    }
    //DHS 12/31: Fix common misspellings, like "ananas" or "apaya"...
    //  this call also LOWERCASES the product name!
    fullProductName = [self fixSentenceTypo:fullProductName];
    //DHS 1/1 fix split words like "hawai ian"
    fullProductName = [self fixSentenceSplits:fullProductName];
    _analyzedCategory = @"EMPTY";
    
    

    NSArray *pItems = [fullProductName componentsSeparatedByString:@" "]; //Separate words
    
    //NSLog(@" Smart?Analyze: [%@]",fullProductName);
    // Get product category / processed / local / bulk / etc....
    //Try matching with built-in CSV file cat.txt first...
    BOOL found = FALSE;
#ifdef USE_CATEGORIES_FILE
    NSArray *a = [occ matchCategory:fullProductName]; //Returns array[4] on matche...
    if (a != nil && a.count >=4)  //Hit?
    {
        //NSLog(@" OCC Cat match [%@]",fullProductName);
        _analyzedCategory  = a[0]; //Get canned data out from array...
        _analyzedProcessed = a[2];
        _analyzedLocal     = a[3];
        if (uom.length < 1) //1/21 Empty UOM (not already set from outside)
            _analyzedUOM       = a[4];
        else
            _analyzedUOM = uom;
        processed = ([_analyzedProcessed.lowercaseString isEqualToString:@"processed"]);
        local     = ([_analyzedLocal.lowercaseString isEqualToString:@"yes"]);
        _analyzedProductName = fullProductName; //Set output product name!
        found = TRUE;
    }
#endif
    //Miss? Try matching words in the product name with some generic lists of items...
    //  Must do it word-by-word, so it's SLOW...
    //Note we bail this section immediately if found is true
    //DHS 6/11 for (NSString *nextWord in pItems) if (nextWord.length > 1) //3/14 ignore 1 char fragments
    for (int pIndex = 0;pIndex<pItems.count;pIndex++)
    {
        NSString *nextWord   = pItems[pIndex];
        NSString *secondWord = nil;  //DHS 6/11 get 2nd word for double keyword ID
        if (pIndex < pItems.count-1)
        {
            secondWord = pItems[pIndex+1]; //Peel of 2nd potential keyword , get lowercase
            secondWord = secondWord.lowercaseString;
        }
        if (found) break;
        NSString *lowerCase = nextWord.lowercaseString; //Always match on lowercase
        lowerCase = [lowerCase   stringByReplacingOccurrencesOfString:@"/" withString:@""]; //Get rid of illegal stuff!

        
        
        if (!found) //DHS 3/4, look thru keywords table if still no match!
        {
            _analyzedUOM = @"n/a";
            NSDictionary *uomdict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                     @"case",   @"beverage",
                                     @"case",   @"bread",
                                     @"qt",     @"dairy",
                                     @"lb",     @"drygoods",
                                     @"lb",     @"produce",
                                     @"lb",     @"protein",
                                     @"case",   @"snacks",
                                    nil];

            NSString *cat = nil; //DHS 3/15 look thru 2 sets of keywords now...
            if (keywords[lowerCase] != nil)
            {
                cat = keywords[lowerCase];
                NSNumber *nn = keywordCats[lowerCase]; //3/13/20
                processed = nn.boolValue;
//                if (cat != nil)
//                    NSLog(@" 3/13/20 KEYWORD (%@) processed kw----> %d",lowerCase,processed);
            }
            //DHS 6/11 try double keywords too if no match...
            if (cat == nil)
            {
                cat = [self matchDoubleKeywords : lowerCase : secondWord];
                processed = foundProcessedInDoubleKw;
//                if (cat != nil)
//                    NSLog(@" 3/13/20 DOUBLE KEYWORD (%@/%@) processed kw----> %d",lowerCase,secondWord,processed);
            }
            
            if (cat != nil) //Kw match?
            {
                if ([cat.lowercaseString isEqualToString:@"drygoods"])
                    _analyzedCategory = @"DRY GOODS";
                else
                    _analyzedCategory = cat.uppercaseString;
                // 7/26  Get bulk/processed flags...
                bulk = TRUE; // 3/13/20 processed = TRUE;
                if ([_analyzedCategory isEqualToString:BEVERAGE_CATEGORY])
                {
                    //Nada for now, use defaults
                }
                else if ([_analyzedCategory isEqualToString:BREAD_CATEGORY])
                {
                    //Nada for now, use defaults
                }
                else if ([_analyzedCategory isEqualToString:DAIRY_CATEGORY])
                {
                    //Nada for now, use defaults
                }
                else if ([_analyzedCategory isEqualToString:DRY_GOODS_CATEGORY])
                {  //DHS 7/30 look for unprocessed items
                    //DHS 3/13/20 handle with new column in DB for (NSString *udTerm in udKeywords)
                    //DHS 3/13/20 handle with new column in DB     if ([fullProductName containsString:udTerm]) processed = FALSE;
                }
                else if ([_analyzedCategory isEqualToString:PAPER_GOODS_CATEGORY])
                {
                    //Nada for now, use defaults
                }
                else if ([_analyzedCategory isEqualToString:PROTEIN_CATEGORY])
                {
                    //DHS 3/13/20 handle with new column in DB processed = FALSE;
                }
                else if ([_analyzedCategory isEqualToString:PRODUCE_CATEGORY])
                {
                    //7/22 look for terms that may indicate we have a processed item here...update to DB ppKeywords
                    //DHS 3/13/20 handle with new column in DB processed = FALSE;
                    //DHS 3/13/20 handle with new column in DB for (NSString *processedTerm in ppKeywords)
                    //DHS 3/13/20 handle with new column in DB {
                    //DHS 3/13/20 handle with new column in DB     if ([fullProductName containsString:processedTerm]) processed = TRUE;
                    //DHS 3/13/20 handle with new column in DB }
                }
                else if ([_analyzedCategory isEqualToString:SNACKS_CATEGORY])
                {
                    bulk = FALSE;
                }
                else if ([_analyzedCategory isEqualToString:SUPPLEMENTS_CATEGORY])
                {
                    bulk = FALSE;
                }
                else if ([_analyzedCategory isEqualToString:SUPPLIES_CATEGORY])
                {
                    //Nada for now, use defaults
                }
                
                //Use our little dictionary above for UOM's, MOVE DICT TO CLASS!
                if (uomdict[cat] != nil) _analyzedUOM = uomdict[cat];
                found = TRUE;
                //NSLog(@" match %@ => %@ processed %d bulk %d uom %@",
                //      lowerCase,cat,processed,bulk,_analyzedUOM);
            }
        }
        //Uom set from outside? Override!
        if (uom.length > 1) _analyzedUOM  = uom;
    } //end for nextword...
    _analyzedProductName = fullProductName; // pass result to output

    //6/14 moved below product check...
    //  lastly, check for NON-product items found in this column... 7/15 only if not found!
    if (!found) for (NSString *nps in nonProducts) //6/14 mutableArray, loaded from parse now
    {
        if ([fullProductName.lowercaseString containsString:nps])
        {
            _nonProduct = TRUE;
            return ANALYZER_NONPRODUCT;
        }
    }
    
    if (!found)
    {
        //NSLog(@" analyze ... no product found [%@]",fullProductName);
        if ([fullProductName isEqualToString:@""]) NSLog(@" EMPTY::::????");
        _majorError = ANALYZER_NO_PRODUCT_FOUND;
        return ANALYZER_NO_PRODUCT_FOUND; //Indicate failure
    }
        
    if ( //Got a product of Hawaii in description? set local flag
        [fullProductName.lowercaseString containsString:@"hawaii"] ||
        [fullProductName.lowercaseString containsString:@"local"] 
        )
        local = TRUE;
    

    //Sanity Check: quantity * price = amount?
    int qint         = [quantity intValue];
    if (qint < 0)
                qint = -1 * qint; //4/5 this happens due to scribbling on the invoice!
    float qfloat     = [quantity floatValue];
    if (qfloat < 0)
              qfloat = -1.0 * qfloat; //4/8 forgot!
    float pfloat     = [price floatValue];
    float afloat     = [amount floatValue];
    //NSLog(@" [%@] q %d p %f a %f",fullProductName,qint,pfloat,afloat);
    //3/22 move from bad math area...
    if (afloat < 0.0) afloat = -1.0 * afloat; //Just negate any negatives!
    if (pfloat < 0.0) pfloat = -1.0 * pfloat;
    NSLog(@" analyze: [%@] priceFix q x p = a %d x %f = %f",fullProductName,qint,pfloat,afloat);
    if (afloat > 10000.0) //Huge Amount? Assume decimal error
    {
        //NSLog(@" ERROR: amount over $10000!!");
        afloat = afloat / 1000.0;
    }
    else if (afloat > 1000.0) //Huge Amount? Assume decimal error
    {
        afloat = afloat / 100.0;
    }
    if (pfloat > 10000.0) //Huge Price? Assume decimal error
    {
        pfloat = pfloat / 1000.0;
    }
    else if (pfloat > 1000.0) //Huge Price? Assume decimal error
    {
        pfloat = pfloat / 100.0;
    }

    //2/14 support float/int quantity
    BOOL zeroQuantity = ((_intQuantity && qint == 0) || (!_intQuantity && qfloat == 0.0));
    BOOL zeroPrice    = (pfloat == 0.0);
    BOOL zeroAmount   = (afloat == 0.0);
    BOOL evenPrice    = [self hasZeroCents:pfloat];
    BOOL evenAmount   = [self hasZeroCents:afloat];
    BOOL priceAmountClose = (ABS(pfloat-afloat) < 1.0);
    
    if (priceAmountClose) //3/15 Price and amount are curiously close together?
    {
        if (evenPrice && !evenAmount) pfloat = afloat; //Wups! fix price
        if (!evenPrice && evenAmount) afloat = pfloat; //Wups! fix amount
    }

    //2/5 Missing 2 / 3 values is a failure...
    if (( zeroPrice    && zeroAmount)   || //2/14 2/3 zero fields?
        ( zeroQuantity && zeroAmount) ||
        ( zeroQuantity && zeroPrice ))
    {
        //NSLog(@" ... 2 out of 3 price columns are zero!");
        _majorError = ANALYZER_BAD_PRICE_COLUMNS;
        //NSLog(@" bad price columns %d %f %f",qint,pfloat,afloat);
        qint   = 1;
        qfloat = 1.0;
        if (!zeroPrice)  //Got a price, assume quantity is 1...
        {
            afloat = pfloat;
        }
        else if (!zeroAmount)  //Got an amount, assume quantity is 1...
        {
            pfloat = afloat;
        }
        else //3/22 wups forgot the 3rd case! valid price but zeroes elsewhere
        {
            afloat = pfloat;
        }
    }
    else //2/5 check for one zero field, fixable!
    {
        if (zeroAmount)
        {
            //NSLog(@"%@ ...ZERO Amount: FIX %f %f",fullProductName,pfloat,afloat);
            if (_intQuantity) //2/14
                afloat = (float)qint * pfloat;
            else
                afloat = qfloat * pfloat;
            aerror = ANALYZER_ZERO_AMOUNT;
            //NSLog(@" ...amountnow %f",afloat);
        }
        else if (zeroQuantity)
        {
            //3/13/20: We can still check if total is even multiple of price!
            int testq   = (floor)((afloat / pfloat) + 0.5);  // calculate integer quantity test
            float test2 = (float)testq * pfloat;
            if (fabsf(test2 - afloat) < 0.03) //3/13/20 within 2 cents?
            {
                // NSLog(@" zero quantity but even price/amount ratio: %d x %f = %f",testq,pfloat,afloat);
                qint = testq;   //3/12/20 save calculated quantity
            }
            else //3/13/20 Cannot reconcile price and amount?
            {
                if (_intQuantity) //3/22 usually means single quantity
                {
                    qint   = 1;       //This is based on HFM invoices!
                    afloat = pfloat; //Price seems to come thru the best...
                }
                else{
                    qfloat = afloat / pfloat;      // 2/14
                    if (qfloat == 0) qfloat = 1.0;
                }
                _majorError = ANALYZER_ZERO_QUANTITY;

            }
        }
        else if (zeroPrice)
        {
            //NSLog(@" ...ZERO PRICE: FIX");
            if (_intQuantity) //2/14
                pfloat = afloat / (float)qint;
            else
                pfloat = afloat / qfloat;
            aerror = ANALYZER_ZERO_PRICE;
        }
        else if ((_intQuantity  && (afloat != (float)qint * pfloat)) ||    //All fields present but still bad math?
                 (!_intQuantity && fabsf(afloat - (qfloat*pfloat)) > 0.01) ) //3/24 add 1cent tolerance for floats
        {
            //NSLog(@" possible math err %@ %d %f %f",
            //      fullProductName,qint,afloat,pfloat);
            if ((pfloat > 100.0 && afloat < 10.0) || (pfloat > 1000.0 && afloat < 100.0)) //4/5 Off by 100 error price?
            {
                //try shrinking the big number!
                float ptfloat = pfloat / 100.0;
                int testq = [self reconcileQuantity:afloat :ptfloat];
                //OK now?
                if (testq > 0) pfloat = ptfloat; //Keep our smaller value!
            }
            else if ((afloat > 100.0 && pfloat < 10.0) || (afloat > 1000.0 && pfloat < 100.0)) //4/5 Off by 100 error amount?
            {
                //try shrinking the big number!
                float atfloat = afloat / 100.0;
                int testq = [self reconcileQuantity:atfloat :pfloat];
                //OK now?
                if (testq > 0) afloat = atfloat; //Keep our smaller value!
            }
            int testq = [self reconcileQuantity:afloat :pfloat];
            if (testq > 0) //4/5 move reconcilation to subroutine, testq must be > 0 or else err!
            {
                //NSLog(@" math OK after all...");
                qint = testq;
            }
            else //3/13/20 Cannot reconcile price and amount?
            {
                if ((_intQuantity && (qint == 1)) || (!_intQuantity && (qfloat == 1.0)) ) //Mismatch price/amount, defer to price!
                {
                    afloat = pfloat; //DHS 3/22 price is correct more often!
                }
                else //Bogus quantity? or price/amount read incompletely?
                {
                        if (_intQuantity)
                            qint = MAX(1,(int)(afloat / pfloat)); //3/22 add zero check
                        else
                            qfloat = afloat/pfloat;
                }
                _majorError = ANALYZER_BAD_MATH;
            } //end else
        }
    }
    if (_intQuantity)
        quantity = [NSString stringWithFormat:@"%d", qint];
    else
        quantity = [NSString stringWithFormat:@"%4.2f", qfloat];
    price    = [self getDollarsAndCentsString  : pfloat];
    amount   = [self getDollarsAndCentsString  : afloat];
    //pass to outputs...
    _analyzedQuantity = quantity;
    _analyzedPrice    = price;
    _analyzedAmount   = amount;
    //NSLog(@" latest qpa %@ / %@ / %@",quantity,price,amount);
    //Handle flags...
    if (local) _analyzedLocal = @"Yes";
    else       _analyzedLocal = @"No";
    
    if (bulk) _analyzedBulkOrIndividual = @"Bulk";
    else      _analyzedBulkOrIndividual = @"Individual";
    
    if (processed) _analyzedProcessed = @"PROCESSED";
    else           _analyzedProcessed = @"UNPROCESSED";
    
    if ([_analyzedUOM isEqualToString: @"n/a"])
    {
        _analyzedBulkOrIndividual = @"n/a";
        _analyzedLocal            = @"n/a";
        _analyzedProcessed        = @"n/a";
    }
    
    _analyzedDateString = [self getDateAsString:_invoiceDate];
    _analyzedLineNumber = [NSString stringWithFormat:@"%d",lineNumber];
    //Just pass across from private -> public here
    _analyzedVendor = vendor;
    
    _analyzeOK = TRUE;
    if (_majorError != 0) aerror = 0; //Major errors trump minor ones!
    _minorError = aerror;
    return 0;
    
} //end analyze

//=============(smartProducts)=====================================================
-(int) reconcileQuantity : (float)afloat : (float)pfloat
{
    //3/13/20: We can still check if total is even multiple of price!
    int testq   = (floor)((afloat / pfloat) + 0.5);  // calculate integer quantity test
    float test2 = (float)testq * pfloat;
    if (fabsf(test2 - afloat) < 0.015) //3/13/20 within 1.5 cents?
    {
        return testq;   //3/12/20 save calculated quantity
    }
    return -1;  //Indicate error still exists!
}

//=============(smartProducts)=====================================================
-(NSString*) matchDoubleKeywords : (NSString*)key1 : (NSString*)key2
{
    NSString *cat = nil;
    //First make normal double keyword
    NSString *dkeytest= [NSString stringWithFormat:@"%@ %@",key1,key2];
    if (dkeytest.length < 5) return cat; //Shorties need not apply!
    cat = dKeywords[dkeytest];  //Match with A B / B A combos of the 2 keywords
    NSNumber *nn = dKeywordCats[dkeytest]; //3/13/20
    foundProcessedInDoubleKw = nn.boolValue;  //3/13/20
    if (cat == nil)
    {
        cat = dKeywordsNo1stChar[dkeytest]; //Try against A B / B A combos missing 1st char
        NSNumber *nn = dKeywordCatsNo1stChar[dkeytest]; //3/13/20
        foundProcessedInDoubleKw = nn.boolValue;  //3/13/20
    }
    return cat;
} //end matchDoubleKeywords



//=============(smartProducts)=====================================================
-(NSString*) getCategoryByProduct : (NSString*)pname
{
    BOOL found = FALSE;
    NSString *foundResult = @"EMPTY";
    NSArray *pItems    = [pname componentsSeparatedByString:@" "]; //Separate words
    for (NSString *nextWord in pItems)
    {
        if (found) break;
        NSString *lowerCase = [nextWord lowercaseString]; //Match lowercase only
        if ([proteinNames indexOfObject:lowerCase] != NSNotFound) //Found?
        {
            found = TRUE;
            foundResult = PROTEIN_CATEGORY;
            _analyzedUOM = @"lb";
        }
    }
    _analyzedCategory = foundResult;
    return foundResult;
}

//=============(smartProducts)=====================================================
-(NSString*) getCategoryByProductAndVendor : (NSString*)pname : (NSString*)vname
{
    return @"EMPTY";
}


//=============(smartProducts)=====================================================
-(NSString *)getDateAsString : (NSDate *) ndate
{
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yy"];
//    [formatter setDateFormat:@"yyyy-MMM-dd HH:mm:ss"];
    NSString *dateString = [formatter stringFromDate:ndate];//pass the date you get from UIDatePicker
    return dateString;
}

//=============(smartProducts)=====================================================
-(NSString*) getDollarsAndCentsString : (float) fin
{
    //NSLog(@" getDollarsAndCentsString %f",fin);
    int d = (int) fin;
    float hcf = 100.0 * fin;
    hcf -= (float)(100*d);
    int c = (int)floor(hcf + 0.5);
    //NSLog(@" dollars %d cents %d",d,c);
    return [NSString stringWithFormat:@"%d.%2.2d",d,c];
}

//=============(smartProducts)=====================================================
// Loads a canned text file containing "a=b" pairs, removes whitespace if needed
-(void) loadRulesTextFile : (NSString*) fname : (BOOL) noWhitespace :
                            (NSMutableArray *) lha : (NSMutableArray *) rha
{
    if (lha == nil || rha == nil) return;
    NSError *error;
    NSArray *sItems;
    NSString *fileContentsAscii;
    NSString *path = [[NSBundle mainBundle] pathForResource:fname ofType:@"txt" inDirectory:@"txt"];
    NSURL *url = [NSURL fileURLWithPath:path];
    fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    if (error != nil)
    {
        NSLog(@" error reading %@ file",fname);
        return;
    }
    sItems    = [fileContentsAscii componentsSeparatedByString:@"\n"];
    [lha removeAllObjects];
    [rha removeAllObjects];
    for (NSString*s in sItems)
    {
        NSArray* lineItems    = [s componentsSeparatedByString:@"="];
        if (lineItems.count == 2) //Got a something = something type string?
        {
            NSString *lhand = lineItems[0];
            NSString *rhand = lineItems[1];
            if (noWhitespace) //Need to change anything?
            {
                lhand = [lhand stringByReplacingOccurrencesOfString:@" " withString:@""];
                rhand = [rhand stringByReplacingOccurrencesOfString:@" " withString:@""];
            }
            [lha addObject:lhand];
            [rha addObject:rhand];
        }
    }
    return;

} //end loadRulesTextFile


//=============(smartProducts)=====================================================
// Goes over splits list,  splits in the sentence are replaced by joined
-(NSString *) fixSentenceSplits : (NSString *)sentence
{
    //Look for common OCR splits (words with splits in them)
    NSString *output = sentence;
    for (int i=0;i<splits.count;i++)
    {
        if ([output containsString:splits[i]])
            output = [output stringByReplacingOccurrencesOfString:splits[i] withString:joined[i]];

    }
    return output;
} //end fixSentenceSplits

//=============(smartProducts)=====================================================
-(NSString*) removePunctuationFromString : (NSString *)s
{
    NSArray *punctuationz = @[@",",@".",@":",@";",@"-",@"_",@"~",@"`",@"\"",
                              @"!",@"@",@"#",@"$",@"%",@"^",@"&",@"/",@"*",@"(",@")",@"+",@"=",@"\'"];
    NSString *sNoPunct = s;
    for (NSString *punc in punctuationz)
    {
        sNoPunct = [sNoPunct stringByReplacingOccurrencesOfString:punc withString:@" "];
    }
    return sNoPunct;
} //end removePunctuationFromString

//=============(smartProducts)=====================================================
// Disassembles sentence, fix typos word-by-word, reassembles sentence
-(NSString *) fixSentenceTypo : (NSString *)sentence
{
    NSString *sNoPunct = [self removePunctuationFromString:sentence]; //Replace punc w/ spaces
    NSArray *sItems    = [[sNoPunct lowercaseString] componentsSeparatedByString:@" "]; //Separate words
    NSMutableArray *ow = [[NSMutableArray alloc] init];
    for (int i=0;i<(int)sItems.count;i++) //Loop over words 3/4 remove wilds, cleanup
        [ow addObject:[self fixTypo:sItems[i]]];
    return [ow componentsJoinedByString:@" "];
} //end fixSentenceTypo

//=============(smartProducts)=====================================================
// 2 table lookup: typos and fixed spellings, simple array match / replace
-(NSString *) fixTypo : (NSString *)testString
{
    NSUInteger index = [typos indexOfObject:testString];
    if (index != NSNotFound)
    {
        return [fixed objectAtIndex:index];
    }
    //DHS 3/15 look for keywords w/ first char missing...
    if (keywordsNo1stChar[testString] != nil)  //These will be in format "category:keyword"
    {
        NSArray *wordz = [keywordsNo1stChar[testString] componentsSeparatedByString:@":"]; //break up a:b
        if (wordz.count > 1) return wordz[1]; //should be proper keyword now
    }
    return testString; //Nothing to fix
} //end fixTypo


@end
