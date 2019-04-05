//
//   _______  ________     ______
//  | ____\ \/ /  _ \ \   / / ___|
//  |  _|  \  /| |_) \ \ / / |
//  | |___ /  \|  __/ \ V /| |___
//  |_____/_/\_\_|     \_/  \____|
//
//  EXPViewController
//  testOCR
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/9 add pull to refresh
//  2/22 add loadingData flag
//  2/22 moved CSV export to mainVC
//  4/5  add sfx

#import "EXPViewController.h"

@interface EXPViewController ()

@end

@implementation EXPViewController


//=============EXP VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    ot = [[OCRTemplate alloc] init];
    ot.delegate = self;
    // 4/5 sfx
    _sfx         = [soundFX sharedInstance];
    
    et = [[EXPTable alloc] init];
    et.delegate     = self;
    et.selectBy     = @"*";
    et.selectValue  = @"*";
    tableName       = @"";
    dbMode          = DB_MODE_NONE;
    batchIDLookup   = @"*";
    invoiceLookup   = @"*";
    vendorLookup    = @"*";
    _scustomer      = @"KCH"; // 3/20
    _detailMode     = FALSE;

    barnIcon    = [UIImage imageNamed:@"barnIcon"];
    bigbuxIcon  = [UIImage imageNamed:@"bigbuxIcon"];
    centIcon    = [UIImage imageNamed:@"centIcon"];
    dollarIcon  = [UIImage imageNamed:@"dollarIcon"];
    factoryIcon = [UIImage imageNamed:@"factoryIcon"];
    globeIcon   = [UIImage imageNamed:@"globeIcon"];
    hiIcon      = [UIImage imageNamed:@"hiIcon"];

    refreshControl = [[UIRefreshControl alloc] init];

    
    sortOptions = @[    @"Invoice Number",@"Batch Counter",@"Vendor",
                        @"Product Name",@"Local",@"Processed"
                        ];

    return self;
}

//=============EXP VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table.delegate = self;
    _table.dataSource = self;
    _table.refreshControl = refreshControl;
    [refreshControl addTarget:self action:@selector(refreshIt) forControlEvents:UIControlEventValueChanged];

    // 1/19 add activity spinner
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];
    
    // Do any additional setup after loading the view.
    _customerLabel.text = _scustomer;
    _titleLabel.text = @"Touch Menu to perform query...";
    _sortButton.hidden   = TRUE;
    _selectButton.hidden = TRUE;
} //end viewDidLoad

//=============OCR MainVC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    batchIDLookup  = @"*";
    vendorLookup   = @"*";
    invoiceLookup  = @"*";
    //Only for detail mode...
    if (!_detailMode) //Normal mode?
    {
        if (_actData.length > 1) //Incoming data?
        {
            NSArray *sitems =  [_actData componentsSeparatedByString:@":"];
            vendorLookup = @"*";
            if (![_searchType isEqualToString:@"I"]) //NOT looking up by invoice?
            {
                if (sitems.count > 0 && sitems[0] != nil) batchIDLookup = sitems[0];
                if (sitems.count > 1 && sitems[1] != nil) vendorLookup  = sitems[1];
            }
            else
            {
                if (sitems.count > 0 && sitems[0] != nil) invoiceLookup = sitems[0];
            }
        }
        sortBy        = sortOptions[1]; //Batch Counter, latest created -> earliest created
        sortAscending = TRUE;
    }
    else
    {
        vendorLookup  = _searchType;
        batchIDLookup = _actData;
    }
    loadingData = FALSE; //DHS 2/22
    //3/20 multi-customer support
    [et setTableName : [NSString stringWithFormat:@"EXP_%@",_scustomer]];
    [self loadEXP];
    [self updateUI];
} //end viewWillAppear


//=============EXP VC=====================================================
-(void) viewDidLayoutSubviews
{
    //add dropshadow to header  2/13 moved here
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:_headerView.bounds];
    _headerView.layer.masksToBounds = NO;
    _headerView.layer.shadowColor = [UIColor blackColor].CGColor;
    _headerView.layer.shadowOffset = CGSizeMake(0.0f, 10.0f);
    _headerView.layer.shadowOpacity = 0.3f;
    _headerView.layer.shadowPath = shadowPath.CGPath;
    [self.view bringSubviewToFront:_headerView];

} //end viewDidLayoutSubviews



//=============EXP VC=====================================================
-(void)refreshIt
{
    NSLog(@" pull to refresh...");
    [self loadEXP];
}


//=============EXP VC=====================================================
- (IBAction)doneSelect:(id)sender
{
    [self dismiss];
}

//=============EXP VC=====================================================
- (IBAction)menuSelect: (id)sender
{
    if (_detailMode) return; //No menu in this mode
    batchIDLookup = @"*";

    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Menu..."];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Database Operation",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Load EXP Table",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self loadEXP];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Load EXP Table By Vendor...",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self promptForEXPVendor];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self makeCancelSound];
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end menuSelect

//=============EXP VC=====================================================
- (IBAction)sortSelect: (id)sender
{
    batchIDLookup = @"*";
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Sort EXP Table By..."];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sort EXP Table By...",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    int i=0;
    
    for (NSString *s in sortOptions)
    {
        UIAlertAction *action = [UIAlertAction actionWithTitle:s
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  self->sortBy = s;
                                                  [self loadEXP];
                                              }];
        [alert addAction:action];
        i++;
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self makeCancelSound];
                                                           }];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
} //end sortSelect


//=============EXP VC=====================================================
- (IBAction)selectSelect: (id)sender
{
    batchIDLookup = @"*";
    et.selectBy     = @"*";
    et.selectValue  = @"*";

    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select By..."];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select By..."
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];

    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Vendor:HPF",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Vendor_key;
                                                   self->et.selectValue = @"HFM";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Vendor:Hawaii Beef Producers",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Vendor_key;
                                                   self->et.selectValue = @"Hawaii Beef Producers";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Local",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Local_key;
                                                   self->et.selectValue = @"Yes";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Not Local",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Local_key;
                                                   self->et.selectValue = @"No";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Processed",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Processed_key;
                                                   self->et.selectValue = @"PROCESSED";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"UnProcessed",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   self->et.selectBy = PInv_Processed_key;
                                                   self->et.selectValue = @"UNPROCESSED";
                                                   [self loadEXP];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"All Fields",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [self loadEXP];
                                                  }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [self makeCancelSound];
                                                  }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end selectSelect

//=============EXP VC=====================================================
- (IBAction)sortDirSelect:(id)sender
{
    sortAscending    = !sortAscending;
    et.sortAscending = sortAscending;
    NSLog(@"ascending = %d",sortAscending);
    [self updateUI];
    [self loadEXP];

}

//=============EXP VC=====================================================
-(void) makeCancelSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 82];
}


//=============EXP VC=====================================================
-(void) makeSegueSound
{
    [self->_sfx makeTicSoundWithPitch : 4 : 84];
    [self->_sfx makeTicSoundWithPitch : 4 : 89];
    [self->_sfx makeTicSoundWithPitch : 4 : 96];
}

//=============EXP VC=====================================================
-(void) makeSelectSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 70];
}



//=============EXP VC=====================================================
-(NSString*) getVendorNameForPrompt : (int) i
{
    NSString *vends[] = {@"HFM",@"Hawaii Beef Producers"};
    if (i < 0) return @"";
    return vends[i];
} //end getVendorNameForPrompt


//=============EXP VC=====================================================
-(void) promptForEXPVendor
{
    
    int nvends = 2; //getVendorNameForPrompt above must match!
    
    UIAlertAction *actions[8]; //May need more...

    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Vendor"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Vendor",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];

    for (int i = 0;i<nvends;i++)
    {
        NSString *vname = [self getVendorNameForPrompt:i];
        actions[i] = [UIAlertAction actionWithTitle:NSLocalizedString(vname,nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self loadEXPByVendor : vname];
                                                          }];
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self makeCancelSound];
                                                           }];

    for (int i = 0;i<nvends;i++)  [alert addAction:actions[i]];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
    
} //end promptForEXPVendor




//=============OCR VC=====================================================
-(void) dismiss
{
    [self makeCancelSound];
    et.parentUp = FALSE; // 2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}


//=============EXP VC=====================================================
-(void) loadEXP
{
    if (loadingData) return; //DHS 2/22
    [self makeSelectSound]; //4/5 almost always invoked by button click...
    [spv start : @"Loading EXP..."];
    loadingData = TRUE;
    _titleLabel.text = @"Loading EXP table...";

    tableName = @"EXP";
    dbMode = DB_MODE_EXP;
    et.sortAscending = sortAscending;
    et.sortBy        = sortBy;
    

    if (!_detailMode) //Normal EXP table examination?
    {
        [et readFromParseAsStrings : FALSE : vendorLookup : batchIDLookup : invoiceLookup];
    }
    else //Just look at one invoice? (comes w/ list of objectIDs)
    {
        [et readFromParseAsStrings : FALSE : vendorLookup : batchIDLookup : invoiceLookup];
    }
    [self updateUI];
}


//=============EXP VC=====================================================
-(void) loadEXPByVendor : (NSString *)v
{
    [self makeSelectSound];
    [spv start : @"Loading Vendor EXP"];
    loadingData = TRUE;
    _titleLabel.text = @"Loading EXP table...";

    tableName = @"EXP";
    vendorLookup = v;
    dbMode = DB_MODE_EXP;
    invoiceLookup = @"*";
    [et readFromParseAsStrings : FALSE : vendorLookup : batchIDLookup : invoiceLookup];
    [self updateUI];
}


//=============EXP VC=====================================================
// A variety of titles may appear depending on mode and sorting
-(void) setLoadedTitle : (NSString *)tableName
{
    //DHS 2/5
    NSString *s;
    if (_detailMode) s = [NSString stringWithFormat:@"Invoice:%@",_invoiceNumber];
    else
    {
        NSString *xtra = @"";
        if ([sortBy isEqualToString:@""]) //No particular sort...
            s = [NSString stringWithFormat:@"[%@%@]",tableName,xtra];
        else{
            if (!_detailMode)
            {
                if ([invoiceLookup isEqualToString:@"*"])  //  2/8 general lookup
                    s = [NSString stringWithFormat:@"Sort by %@",sortBy];
                else                                        // 2/8 invoice lookup
                    s = [NSString stringWithFormat:@"Invoice %@",invoiceLookup];
            }
            else  s = [NSString stringWithFormat:@"Invoice %@",_actData];
        }
    }
    if (et.expos.count == 0) s = @"No Records Found...";
    _titleLabel.text = s;
} //end setLoadedTitle

//=============EXP VC=====================================================
-(void) updateUI
{
    if (sortAscending)
        [_sortDirButton setBackgroundImage:[UIImage imageNamed:@"arrUp"] forState:UIControlStateNormal];
    else
        [_sortDirButton setBackgroundImage:[UIImage imageNamed:@"arrDown"] forState:UIControlStateNormal];

//    NSString *vlab = @"";
//    if ([vendor isEqualToString:@""] )
//        vlab = @"Touch Menu to begin...";
//    else
//        vlab = [NSString stringWithFormat:@"%@:%@",tableName,vendor];
//    _titleLabel.text = vlab;
}

#pragma mark - UITableViewDelegate


//=============EXP VC=====================================================
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    if (dbMode == DB_MODE_EXP)
    {
        EXPCell *cell = (EXPCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil)
        {
            cell = [[EXPCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        EXPObject *e = [et.expos objectAtIndex:row];
        BOOL local     =  ([e.local.lowercaseString     isEqualToString:@"yes"]);
        BOOL processed =  ([e.processed.lowercaseString isEqualToString:@"processed"]);
        if (local) cell.localIcon.image         = hiIcon;
        else cell.localIcon.image               = globeIcon;
        if (processed) cell.processedIcon.image = factoryIcon;
        else cell.processedIcon.image           = barnIcon;

        double total = [e.total doubleValue];
        if (total > 100.0)      cell.priceIcon.image = bigbuxIcon;
        else if (total > 10.0)  cell.priceIcon.image = dollarIcon;
        else                    cell.priceIcon.image = centIcon;

        cell.label1.text = [NSString stringWithFormat:@"%@",e.productName];
        cell.label2.text = [NSString stringWithFormat:@"%@ at %@ = %@",
                            e.quantity,e.pricePerUOM,e.total];
        NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MM/dd/yy"];
        NSString *sfd = [formatter stringFromDate:e.expdate];

        cell.label3.text = [NSString stringWithFormat:@"Invoice %@ Date %@ File %@",
                            e.invoiceNumber,sfd,e.PDFFile];
        cell.doblabel.text = e.vendor;
        //        cell.label4.text = e.vendor;
        return cell;
    }
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    return cell;
} //end cellForRowAtIndexPath


//=============EXP VC=====================================================
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (int)et.expos.count;
}

//=============EXP VC=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}


//=============EXP VC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    selectedRow = (int)indexPath.row;
    //sdata  = [act getData:row];
    EXPObject *e = [et.expos objectAtIndex:selectedRow];
    [self performSegueWithIdentifier:@"expDetailSegue" sender:e];

}

//=============EXP VC=====================================================
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [self makeSegueSound];
    if([[segue identifier] isEqualToString:@"expDetailSegue"])
    {
        //Just hand all our PFObjects to the detailVC...
        EXPDetailVC *vc = (EXPDetailVC*)[segue destinationViewController];
        vc.allObjects  = [[NSArray alloc]initWithArray:et.expos];
        vc.detailIndex = selectedRow;
        vc.scustomer   = _scustomer;
    }
} //end prepareForSegue


#pragma mark - EXPTableDelegate

//============<EXPTableDelegate>====================================================
- (void)didReadEXPTableAsStrings : (NSString *)s
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_table reloadData];
        self->loadingData = FALSE;
        [self->spv stop];
        [self setLoadedTitle : @"EXP"];
        self->_sortButton.hidden   = FALSE;
        self->_selectButton.hidden = FALSE;
    });
}



#pragma mark - invoiceTableDelegate

//=============EXP VC=====================================================
- (void)didReadInvoiceTableAsStrings : (NSMutableArray*)a
{
    [_table reloadData];
    loadingData = FALSE;
    [spv stop];
    [self setLoadedTitle : @"Invoices"];

}

#pragma mark - OCRTemplateDelegate

//=============EXP VC=====================================================
- (void)didReadTemplateTableAsStrings : (NSMutableArray*) a
{
    [_table reloadData];

}

@end
