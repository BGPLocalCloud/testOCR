//
//   __  __       _    __     ______
//  |  \/  | __ _(_)_ _\ \   / / ___|
//  | |\/| |/ _` | | '_ \ \ / / |
//  | |  | | (_| | | | | \ V /| |___
//  |_|  |_|\__,_|_|_| |_|\_/  \____|
//
//  MainVC.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
// PDF Image conversion?
//   https://github.com/a2/FoodJournal-iOS/tree/master/Pods/UIImage%2BPDF/UIImage%2BPDF
//  1/6 add pull to refresh
//  1/9 Make sure batch gets created AFTER parse DB is up!
//  1/14 Add invoiceVC hookup, bold menu titles too!
//  2/5  Add vendors, make sure loaded b4 batch segue
//  2/8  Changed batchListChoiceMenu
//  2/9  Merged PDF / OCR cache clears
//  2/22 Moved CSV Export from expVC
//  2/23 Fix array -> mutableArray conversion bug
//  3/12 Add help option
//  3/20 New: multi-customer support, new folder structure

#import "MainVC.h"

@interface MainVC ()

@end

@implementation MainVC

//=============OCR MainVC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    act = [[ActivityTable alloc] init];
    act.delegate = self;
    
    emptyIcon     = [UIImage imageNamed:@"emptyDoc"];
    dbIcon        = [UIImage imageNamed:@"lildbGrey"];
    batchIcon     = [UIImage imageNamed:@"multiNOT"];
    errIcon       = [UIImage imageNamed:@"redX"];
    versionNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    oc = [OCRCache sharedInstance];
    pc = [PDFCache sharedInstance];
    // 1/4 add genparse to clear activities
    gp = [[GenParse alloc] init];
    gp.delegate = self;
    et = [[EXPTable alloc] init];
    et.delegate = self;

    ecount = 0;
    
    vv = [Vendors sharedInstance];
    
    refreshControl = [[UIRefreshControl alloc] init];
    batchPFObjects = nil;
    
    fixingErrors = TRUE;
    
    fatalErrorSelect = FALSE;
    
    scustomer = @"KCH";  //DHS 3/20

    //Test only, built-in OCR crap...
    //[self loadBuiltinOCRToCache];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReadBatchByIDs:)
                                                 name:@"didReadBatchByIDs" object:nil];
    
    
    return self;
}

//=============OCR MainVC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    int xi,yi,xs,ys;
    
    //CLUGEY! makes sure landscape òrientation doesn't set up NAVbar wrong`
    int tallestXY  = viewHit;
    int shortestXY = viewWid;
    if (shortestXY > tallestXY)
    {
        tallestXY  = viewWid;
        shortestXY = viewHit;
    }
    xs = shortestXY;
    ys = 80;
    xi = 0;
    yi = tallestXY - ys;
    nav = [[NavButtons alloc] initWithFrameAndCount: CGRectMake(xi, yi, xs, ys) : 4];
    nav.delegate = self;
    [self.view addSubview: nav];
    [self setupNavBar];

    _table.delegate = self;
    _table.dataSource = self;
    _table.refreshControl = refreshControl;
    [refreshControl addTarget:self action:@selector(refreshIt) forControlEvents:UIControlEventValueChanged];
    
    //add a lil dropshadow
    _logoView.layer.shadowColor   = [UIColor blackColor].CGColor;
    _logoView.layer.shadowOffset  = CGSizeMake(0.0f,10.0f);
    _logoView.layer.shadowOpacity = 0.3f; 
    _logoView.layer.shadowRadius  = 10.0f;
    //below top label too...
    _logoLabel.layer.shadowColor   = [UIColor blackColor].CGColor;
    _logoLabel.layer.shadowOffset  = CGSizeMake(0.0f,10.0f);
    _logoLabel.layer.shadowOpacity = 0.3f;
    _logoLabel.layer.shadowRadius  = 10.0f;
    // 1/19 Add spinner busy indicator...
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, viewWid, viewHit)];
    [self.view addSubview:spv];

} //end viewDidLoad

//=============OCR MainVC=====================================================
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}



//=============OCR MainVC=====================================================
-(void)refreshIt
{
    //NSLog(@" pull to refresh...");
    [act readActivitiesFromParse:nil :nil];
}


//=============OCR MainVC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;
    
}

//=============OCR MainVC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [act readActivitiesFromParse:nil :nil];
    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _customerLabel.text = mappDelegate.selectedCustomerFullName;
    //[self testit];
}


//=============OCR MainVC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    //NSLog(@"mainvc viewDidAppear...");
    [super viewDidAppear:animated];
    
//    if ([PFUser currentUser] != nil && (PFUser.currentUser.objectId != nil)) //Logged in?
    if ([PFUser currentUser] == nil) //NOT Logged in?
    {
        loginMode = @"login";
        [self performSegueWithIdentifier:@"loginSegue" sender:@"mainVC"];
    }
    else NSLog(@" ...logged into Parse");
    _versionLabel.text = [NSString stringWithFormat:@"V %@",versionNumber];
    [self testit];
}


//=============OCR MainVC=====================================================
- (IBAction)eSelect:(id)sender  //estie eeg
{
    ecount++;
    if (ecount % 1 == 0) [self admin];
}

//=============OCR MainVC=====================================================
-(void) admin
{
    NSLog(@" admin");
    loginMode = @"admin";
    [self performSegueWithIdentifier:@"loginSegue" sender:@"mainVC"];
}

//=============OCR MainVC=====================================================
-(void) menu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Main Functions"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Main Functions",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Change Customer",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self customerMenu];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Template",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"addTemplateSegue" sender:@"mainVC"];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Edit Template",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"templateSegue" sender:@"mainVC"];
                                                          }]];
//    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Load Comparison EXP File...",nil)
//                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
//                                                              [self performSegueWithIdentifier:@"comparisonSegue" sender:@"mainVC"];
//                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Clear Local Caches",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearCacheMenu];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Clear Activities",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearActivityMenu];
                                                          }]];
     [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"PDF Analyzer",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self performSegueWithIdentifier:@"analyzerSegue" sender:@"mainVC"];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Logout From Dropbox",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [DBClientsManager unlinkAndResetClients];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Logout From Sashido",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [PFUser logOut];
                                                  self->loginMode = @"login";
                                                  [self performSegueWithIdentifier:@"loginSegue" sender:@"mainVC"];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Help",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self performSegueWithIdentifier:@"helpSegue" sender:@"mainVC"];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];


} //end menu



//=============OCR MainVC=====================================================
// 3/20 New: multi-customer support
-(void) customerMenu
{
    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *cstr = [NSString stringWithFormat:@"Current Customer [%@]",mappDelegate.selectedCustomer];
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:cstr];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(cstr,nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    int i = 0;
    for (NSString *nextCust in mappDelegate.cust.customerNames)
    {
        NSString *cfull = mappDelegate.cust.fullNames[i];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(nextCust,nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [mappDelegate updateCustomerDefaults:nextCust :cfull];
                                                      self->_customerLabel.text = cfull;
                                                  }]];
        i++;
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    
    
} //end customerMenu

//=============OCR MainVC=====================================================
// For selecting databases...
-(void) dbmenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Database Table"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Select Database Table",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert setValue:tatString forKey:@"attributedTitle"];

    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"EXP Table",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                                              self->scustomer = mappDelegate.selectedCustomer; //3/20
                                                              [self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
                                                          }]];
    for (int vindex = 0;vindex < vv.vcount;vindex++)
    {
        NSString *s = [vv getNameByIndex:vindex]; //DHS 3/6
        NSString *nextChoice = [NSString stringWithFormat:@"%@ Invoices",s];
            [alert addAction: [UIAlertAction actionWithTitle:nextChoice
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           self->selVendor = s;
                                                           [self performSegueWithIdentifier:@"invoiceSegue" sender:@"mainVC"];
                                                       }]];
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
} //end dbmenu

//=============OCR MainVC=====================================================
-(void) dumpSettings
{
    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *s = [mappDelegate.settings getDumpString];
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Settings Dump"
                                        message:s
                                 preferredStyle:(UIAlertControllerStyle)UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:(UIAlertActionStyle)UIAlertActionStyleCancel
                                                      handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
    
}


//=============OCR MainVC=====================================================
// if you click on a batch item, this gets invoked
// TRY CHANGING TITLE FONT SIZE AND COLOR
//   https://stackoverflow.com/questions/31662591/swift-how-to-change-uialertcontrollers-title-color
//   https://exceptionshub.com/uialertcontroller-change-font-color.html
//  This looks the best
//    https://stackoverflow.com/questions/26460706/uialertcontroller-custom-font-size-color
//  2/8 cleanup / add isbatch test
-(void) batchListChoiceMenu
{
    NSArray  *sItems  = [sdata componentsSeparatedByString:@":"]; //Look at the data for this item...
    BOOL isBatch = (sItems.count > 1); //Is this a batch started / completed item?
    if (sItems.count > 2) scustomer = sItems[2];  //3/20
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Batch Retreival"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Batch Retreival",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Get EXP records",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  if (isBatch) self->stype = @"E"; //Lookup by batch
                                                  else         self->stype = @"I"; //Lookup by invoice
                                                  [self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Get Invoices",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  self->stype = @"I";
                                                  [self performSegueWithIdentifier:@"invoiceSegue" sender:@"mainVC"];
                                              }]];
    if (isBatch) //2/8 batch has extra choices...
    {
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"View/Fix Errors",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      self->fixingErrors = TRUE;
                                                      [self performSegueWithIdentifier:@"errorSegue" sender:@"mainVC"];
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"View/Fix Warnings",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      self->fixingErrors = FALSE;
                                                      [self performSegueWithIdentifier:@"errorSegue" sender:@"mainVC"];
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Error Helper",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [self performSegueWithIdentifier:@"errorHelperSegue" sender:@"mainVC"];
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Get Report",nil)
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [self performSegueWithIdentifier:@"batchReportSegue" sender:@"mainVC"];
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Export EXP to Excel",nil)  // 2/22
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                      [self exportEXPToExcel];
                                                  }]];
    } //end isbatch
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end menu


//=============OCR MainVC=====================================================
// Yes/No for ALL cache clear...
-(void) clearCacheMenu
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear Local Caches?\n(Cannot be undone!)",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            [self->oc clearHardCore];
                                                            [self->pc clearHardCore];
                                                        }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO",nil)
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end clearCacheMenu



//=============OCR MainVC=====================================================
// Yes/No for activity table clear...
-(void) clearActivityMenu
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear Activities?\n(Cannot be undone!)",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            [self->spv start:@"Clear Activities..."];
                                                            [self->gp deleteAllByTableAndKey:@"activity" :@"*" :@"*"];
                                                        }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO",nil)
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:YES completion:nil];
} //end clearActivityMenu




#define NAV_HOME_BUTTON 0
#define NAV_DB_BUTTON 1
#define NAV_SETTINGS_BUTTON 2
#define NAV_BATCH_BUTTON 3

//=============OCR MainVC=====================================================
-(void) setupNavBar
{
    nav.backgroundColor = [UIColor redColor];
//    [nav setSolidBkgdColor:[UIColor colorWithRed:0.9 green:0.8 blue:0.7 alpha:1] :0.5];
//
//
//     -(void) setSolidBkgdColor : (UIColor*) color : (float) alpha
//]
//    nav.backgroundColor = [UIColor colorWithRed:0.9 green:0.8 blue:0.7 alpha:1];
    // Menu Button...
    [nav setHotNot         : NAV_HOME_BUTTON : [UIImage imageNamed:@"HamburgerHOT"]  :
     [UIImage imageNamed:@"HamburgerNOT"] ];
    [nav setLabelText      : NAV_HOME_BUTTON : NSLocalizedString(@"MENU",nil)];
    [nav setLabelTextColor : NAV_HOME_BUTTON : [UIColor blackColor]];
    [nav setHidden         : NAV_HOME_BUTTON : FALSE];
    // DB access button...
    [nav setHotNot         : NAV_DB_BUTTON : [UIImage imageNamed:@"dbNOT"]  :
     [UIImage imageNamed:@"dbHOT"] ];
    //[nav setCropped        : NAV_DB_BUTTON : 0.01 * PORTRAIT_PERCENT];
    [nav setLabelText      : NAV_DB_BUTTON : NSLocalizedString(@"DB",nil)];
    [nav setLabelTextColor : NAV_DB_BUTTON : [UIColor blackColor]];
    [nav setHidden         : NAV_DB_BUTTON : FALSE];
    // other button...
    [nav setHotNot         : NAV_SETTINGS_BUTTON : [UIImage imageNamed:@"grafHOT"]  :
     [UIImage imageNamed:@"grafNOT"] ];
    [nav setLabelText      : NAV_SETTINGS_BUTTON : NSLocalizedString(@"Outputs",nil)];
    [nav setLabelTextColor : NAV_SETTINGS_BUTTON : [UIColor blackColor]];
    [nav setHidden         : NAV_SETTINGS_BUTTON : FALSE]; //10/16 show create even logged out...

    [nav setHotNot         : NAV_BATCH_BUTTON : [UIImage imageNamed:@"multiNOT"]  :
     [UIImage imageNamed:@"multiHOT"] ];
    [nav setLabelText      : NAV_BATCH_BUTTON : NSLocalizedString(@"Batch",nil)];
    [nav setLabelTextColor : NAV_BATCH_BUTTON : [UIColor blackColor]];
    [nav setHidden         : NAV_BATCH_BUTTON : FALSE]; //10/16 show create even logged out...
    //Set color behind NAV buttpns...
    [nav setSolidBkgdColor:[UIColor colorWithRed:0.9 green:0.8 blue:0.7 alpha:1] :1];
    
    //REMOVE FOR FINAL DELIVERY
    //    vn = [[UIVersionNumber alloc] initWithPlacement:UI_VERSIONNUMBER_TOPRIGHT];
    //    [nav addSubview:vn];
    
}


//=============OCR MainVC=====================================================
// Handles last minute VC property setups prior to segues
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //NSLog(@" prepareForSegue: %@ sender %@",[segue identifier], sender);
    if([[segue identifier] isEqualToString:@"loginSegue"])
    {
        LoginVC *vc = (LoginVC*)[segue destinationViewController];
        vc.mode  = loginMode;
    }
    else if([[segue identifier] isEqualToString:@"addTemplateSegue"])
    {
        AddTemplateViewController *vc = (AddTemplateViewController*)[segue destinationViewController];
        vc.step = 0;
        vc.needPicker = TRUE;
    }
    else if([[segue identifier] isEqualToString:@"expSegue"])
    {
        EXPViewController *vc = (EXPViewController*)[segue destinationViewController];
        vc.actData    = sdata; //Pass selected objectID's from activity, if any...
        vc.searchType = stype;
        vc.detailMode = FALSE;
        vc.scustomer  = scustomer; //3/20
    }
    else if([[segue identifier] isEqualToString:@"invoiceSegue"])
    {
        InvoiceViewController *vc = (InvoiceViewController*)[segue destinationViewController];
        vc.vendor        = @"*"; //2/9 Default to all vendors, batches and invoices
        vc.batchID       = @"*";
        vc.invoiceNumber = @"*";
        if (sdata != nil) // Called from batch popup -> invoices? get batch#
        {
            //Get batch ID for invoice lookup...
            NSArray  *sdItems = [sdata componentsSeparatedByString:@":"];
            if (sdItems != nil)
            {
                if (sdItems.count == 1) //EXP/Invoice item selected
                {
                    vc.invoiceNumber = sdItems[0];
                }
                else //Batch item selected
                {
                    vc.batchID = sdItems[0];
                }
            } //end sdITems...
        } //end sdata...
    }
    else if([[segue identifier] isEqualToString:@"errorSegue"])
    {
        ErrorViewController *vc = (ErrorViewController*)[segue destinationViewController];
        vc.batchData    = sdata;
        vc.fixingErrors = fixingErrors;
    }
    else if([[segue identifier] isEqualToString:@"errorHelperSegue"])
    {
        ErrorHelperVC *vc = (ErrorHelperVC*)[segue destinationViewController];
        vc.batchData      = sdata;
    }
    else if([[segue identifier] isEqualToString:@"batchReportSegue"])
    {
        BatchReportController *vc = (BatchReportController*)[segue destinationViewController];
        NSArray  *sdItems = [sdata componentsSeparatedByString:@":"]; //Break up batch data
        if (sdItems != nil && sdItems.count > 0) //Got something?
        {
            NSString *batchID = sdItems[0];
            //NSLog(@" list[%d] bid %@",row,batchID);
            for (PFObject *pfo in batchPFObjects)
            {
                if ([pfo[PInv_BatchID_key] isEqualToString:batchID]) //Batch Match? Look for errors
                {
                    vc.pfo = pfo;
                    break;
                }
            }
        }
    }

}


#pragma mark - UITableViewDelegate


//=============OCR MainVC=====================================================
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    activityCell *cell = (activityCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[activityCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }

    NSString *atype = [act getType:row];
    NSString *atypeMatch = atype.lowercaseString;
    NSString *adata = [act getData:row];
    NSString *firstRowOutput  = atype;
    NSString *secondRowOutput = adata;

    UIImage *ii = emptyIcon;
    cell.badgeLabel.hidden  = TRUE;
    cell.checkmark.hidden   = TRUE; //No checkmarks!
    cell.badgeLabel.hidden  = TRUE;
    cell.badgeWLabel.hidden = TRUE;

    if ([atypeMatch containsString:@"error"]) //Errors get big red X
    {
        ii = errIcon;
    }
    //Batch Acdtivity:Batch cell has a badge(errorcount) and custom color...
    else if ([atypeMatch containsString:@"batch"] && (batchPFObjects != nil))
    {
        ii = batchIcon;
        NSArray  *adItems = [adata componentsSeparatedByString:@":"]; //Break up batch data
        if (adItems != nil && adItems.count > 0) //Got something?
        {
            NSString *batchID = adItems[0];
            //NSLog(@" list[%d] bid %@",row,batchID);
            cell.checkmark.hidden = FALSE; //Assume no errs...
            for (PFObject *pfo in batchPFObjects)
            {
                if ([pfo[PInv_BatchID_key] isEqualToString:batchID]) //Batch Match? Look for errors
                {
                    int bcount = [bbb countCommas:pfo[PInv_BatchErrors_key]];
                    int fcount = [bbb countCommas:pfo[PInv_BatchFixed_key]];;
                    int errCount = bcount - fcount;  //# errs = total errs - fixed errs
                    if (errCount > 0)
                    {
                        cell.badgeLabel.hidden             = FALSE;
                        cell.badgeLabel.text               = [NSString stringWithFormat:@"%d",errCount];
                        cell.badgeLabel.layer.cornerRadius = 10;
                        cell.badgeLabel.clipsToBounds      = YES;
                        cell.checkmark.hidden              = TRUE;
                    }
                    else{ //No errors, show checkmark
                    }
                    bcount = [bbb countCommas:pfo[PInv_BatchWarnings_key]];
                    fcount = [bbb countCommas:pfo[PInv_BatchWFixed_key]];;
                    int wCount = bcount - fcount;  //# errs = total errs - fixed errs
                    if (wCount > 0)
                    {
                        cell.badgeWLabel.hidden             = FALSE;
                        cell.badgeWLabel.text               = [NSString stringWithFormat:@"%d",wCount];
                        cell.badgeWLabel.layer.cornerRadius = 10;
                        cell.badgeWLabel.clipsToBounds      = YES;
                    }
                } //end batch match
            } //end for (PFOb....)
        }    //end aditems...
    }       //end type.lower
    else //Non-batch and non-error activity?
    {
        //For invoice, exp, etc... make sure invoice number is indicated
        if ([atypeMatch containsString:@"invoice"])
        {
            ii = dbIcon;
            secondRowOutput = [NSString stringWithFormat:@"Invoice:%@",adata];
        }
        
        if ([atypeMatch containsString:@"exp"])
        {
            ii = dbIcon;
            secondRowOutput = [NSString stringWithFormat:@"Invoice:%@",adata];
        }

    } //end else
    //Date -> String, why isn't this in just one call???
    NSDate *activityDate = [act getDate:row];
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy  HH:mmv:SS"];
    NSString *sfd = [formatter stringFromDate:activityDate];
    
    //Fill out Cell UI
    //Top Bold label in the cell...
    cell.topLabel.text    = firstRowOutput;
    // ..next row, normal text (info etc...)
    cell.bottomLabel.text = secondRowOutput;
    // LH batch icon, db icon, etc...
    cell.icon.image       = ii;
    // small grey label bottom cell
    cell.dateLabel.text   = sfd;

    return cell;
} //end cellForRowAtIndexPath


//=============OCR MainVC=====================================================
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [act getReadCount];
}

//=============OCR MainVC=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

//=============OCR MainVC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int row          = (int)indexPath.row;
    sdata            = [act getData:row];
    if ([act isFatalError:row]) //Fatal error goes to batch report
    {
        [self performSegueWithIdentifier:@"batchReportSegue" sender:@"mainVC"];
    }
    else //DHS 2/27 Not an error? put up menu
        [self batchListChoiceMenu];
}

//=============OCR MainVC=====================================================
// Finds batches in our activity list, gets error/other info
-(void) getBatchInfo
{
    [spv start:@"Load Batches..."];
    bbb = [BatchObject sharedInstance]; //No need for delegate, just hook up batch
    NSMutableArray *bids = [[NSMutableArray alloc] init];
    for (int i=0;i< [act getReadCount];i++)
    {
        NSString *actData = [act getData:i]; //Get batch data, Separate fields
        NSArray  *aItems  = [actData componentsSeparatedByString:@":"];
        if (aItems.count >= 2) //3/22 Batch activities have 2 or more items
        {
            NSString *izzitAnID = aItems[0];
            if ([izzitAnID containsString:@"B_"]) [bids addObject:izzitAnID];
        }
    }
    [bbb readFromParseByIDs:bids];
} //end getBatchInfo

//=============OCR MainVC=====================================================
- (void)didReadBatchByIDs:(NSNotification *)notification
{
    //Should be pfobjects?
    batchPFObjects = [notification.object mutableCopy]; //DHS 2/23
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self->_table reloadData];
    });
} //end didReadBatchByIDs



#pragma mark - NavButtonsDelegate
//=============OCR MainVC=====================================================
-(void)  didSelectNavButton: (int) which
{
    //NSLog(@"   didselectNavButton %d",which);
    // [_sfx makeTicSoundWithPitch : 8 : 50 + which];
    
    if (which == 0) //THis is now a multi-function popup...
    {
        [self menu];
        //[self performSegueWithIdentifier:@"cloudSegue" sender:@"feedCell"];
    }
    else if (which == 1) //THis is now a multi-function popup...
    {
        [self dbmenu];
    }
    else if (which == 2) //Templates / settings?
    {
        
        NSString *chartitAppURL = @"Chartit://";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:chartitAppURL]];

//        if ( canOpenUrl ) [[UIApplication sharedApplication]
//                           openURL:[NSURL URLWithString:url]];
        
//        To find all the url, go to this page: http://handleopenurl.com/
        //        [self performSegueWithIdentifier:@"helpSegue" sender:@"mainVC"];

       // [self testit];
       // return;
       // [self performSegueWithIdentifier:@"templateSegue" sender:@"mainVC"];
    }
    if (which == 3 && vv.loaded) //batch? (2/5 make sure vendors are there first!)
    {
        [self performSegueWithIdentifier:@"batchSegue" sender:@"mainVC"];
    }

} //end didSelectNavButton

//=============OCR MainVC=====================================================
-(void) loadBuiltinOCRToCache
{
    NSString *fname = @"beef";
    NSError *error;
    NSString *path = [[NSBundle mainBundle] pathForResource:fname ofType:@"txt" inDirectory:@"txt"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSString *fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    NSString *fullImageFname = @"hawaiiBeefInvoice.jpg";
    [oc addOCRTxtWithRect : fullImageFname : CGRectMake(0, 0, 1275, 1650) : fileContentsAscii];

    fname = @"hfm";
    path = [[NSBundle mainBundle] pathForResource:fname ofType:@"txt" inDirectory:@"txt"];
    url = [NSURL fileURLWithPath:path];
    fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    fullImageFname = @"hfm90.jpg";
    [oc addOCRTxtWithRect : fullImageFname : CGRectMake(0, 0, 1777, 1181) : fileContentsAscii];
}

//=============OCR MainVC=====================================================
-(NSDictionary*) readTxtToJSON : (NSString *) fname
{
    NSError *error;
    NSArray *sItems;
    NSString *fileContentsAscii;
    NSString *path = [[NSBundle mainBundle] pathForResource:fname ofType:@"txt" inDirectory:@"txt"];
    //NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL fileURLWithPath:path];
    fileContentsAscii = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
    if (fileContentsAscii == nil) return nil;
    sItems    = [fileContentsAscii componentsSeparatedByString:@"\n"];
    NSData *jsonData = [fileContentsAscii dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *jdict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                          options:NSJSONReadingMutableContainers error:&e];
    if (e != nil) NSLog(@" Error: %@",e.localizedDescription);
    return jdict;
}

int currentYear = 2019;

//=============OCR MainVC=====================================================
-(void) testit
{
    
//    [self performSegueWithIdentifier:@"addTemplateSegue" sender:@"mainVC"];
    return;
//    smartProducts *smartp = [[smartProducts alloc] init];
//    [smartp saveKeywordsAndTyposToParse];
//    return;

    
//    [self performSegueWithIdentifier:@"errorSegue" sender:@"mainVC"];
//    return;
    //[et readFullTableToCSV:0];
    
//    GenParse *gp = [[GenParse alloc] init];
//    [gp deleteAllByTableAndKey:@"activity" :@"*" :@"*"];
//    NSLog(@" deletit?");
   // smartProducts *smartp = [[smartProducts alloc] init];
    
//    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//    DropboxTools *dbt = [[DropboxTools alloc] init];
//    [dbt getFolderList : mappDelegate.settings.templateFolder];

    return;
    
//    NSDictionary *d    = [self readTxtToJSON:@"hfmpages"];
//    OCRDocument *od = [[OCRDocument alloc] init];
//
//    NSString *p = @"I. 64";
//    [od cleanupPrice:p];
//
//    [od setupDocumentAndParseJDON : @"hfmpages" :d :FALSE];
//    return;

}


//=============OCR MainVC=====================================================
-(void) exportEXPToExcel  //2/22
{
    NSArray  *sItems  = [sdata componentsSeparatedByString:@":"]; //Look at the data for this item...
    BOOL isBatch = (sItems.count > 1); //Is this a batch started / completed item?
    if (isBatch)
    {
        [self->spv start:@"Get CSV List..."];
        NSString *batchID = sItems[0];
        [et setTableNameForCurrentCustomer]; //DHS 3/20
        [et readFullTableToCSV:0 :TRUE : batchID];
    }
    
}

//=============OCR MainVC=====================================================
-(void) errorMessage : (NSString *) title :(NSString *) msg
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(title,nil)  message:msg
                                preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
     [self presentViewController:alert animated:YES completion:nil];

} //end errorMessage


// https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_pdf/dq_pdf.html


//=============OCR MainVC=====================================================
// This produces a file but it doesn't open up in acrobat
-(void) downloadPDF : (NSString *) urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSLog(@" download PDF from [%@]",urlString);
    [[SessionManager sharedSession] startDownload:url];
    
}

#pragma mark - ActivityTableDelegate

//=============OCR MainVC=====================================================
- (void)didReadActivityTable
{
    //NSLog(@"  MainVC:got act table...");
    [_table reloadData];
    [self getBatchInfo]; //Yet another parse pass...
}

//=============OCR MainVC=====================================================
- (void)errorReadingActivities : (NSString *)errmsg
{
    NSLog(@" act table err %@",errmsg);
}


#pragma mark - EXPTableDelegate

//============<EXPTableDelegate>====================================================
- (void)didReadFullTableToCSV : (NSString *)s
{
    NSLog(@" got csv list %@",s);
    //3/25 wups, stop spinner!
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });
    NSArray *testit = [s componentsSeparatedByString:@"\n"];
    if (testit.count < 3) //Nothin?
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self errorMessage:@"Cannot export to Excel" :@"No Records Found"];
        });
    }
    else [self mailit: s]; //OK? send CSV out via email

} //end didReadFullTableToCSV

//============<EXPTableDelegate>====================================================
- (void)errorReadingFullTableToCSV : (NSString *)err;
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop]; //3/25
        [self errorMessage:@"Error exporting to Excel" : err];
    });

}


#pragma mark - GenParseDelegate
//=============<GenParseDelegate>=====================================================
- (void)didDeleteAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshIt];
    });
}

//=============<GenParseDelegate>=====================================================
- (void)errorDeletingAllByTableAndKey : (NSString *)s1 : (NSString *)s2 : (NSString *)s3
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshIt];
    });

}

//=============OCR VC=====================================================
//Doesn't work in simulator??? huh??
-(void) mailit : (NSString *)s
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        [mail setSubject:@"EXP CSV output"];
        [mail setMessageBody:@"...see text attachment" isHTML:NO];
        NSData *sdata = [s dataUsingEncoding:NSUTF8StringEncoding];
        NSDate *today = [NSDate date];
        NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MM_dd_yyyy"];
        NSString *sfd = [formatter stringFromDate:today];
        NSString *fname = [NSString stringWithFormat:@"EXP_%@.csv",sfd];
        [mail addAttachmentData:sdata mimeType:@"text/plain"  fileName:fname];
        [mail setToRecipients:@[@"fraktalmaui@gmail.com"]];
        [self presentViewController:mail animated:YES completion:NULL];
    }
    else
    {
        NSLog(@"This device cannot send email");
    }
}

#pragma mark - MFMailComposeViewControllerDelegate


//==========FeedVC=========================================================================
- (void) mailComposeController:(MFMailComposeViewController *)controller    didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    NSLog(@" mailit: didFinishWithResult...");
    switch (result)
    {
        case MFMailComposeResultSent:
            NSLog(@" mail sent OK");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    [controller dismissViewControllerAnimated:YES completion:NULL];
}


@end



