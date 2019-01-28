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

#import "MainVC.h"

@interface MainVC ()

@end

@implementation MainVC

//=============OCR MainVC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    act = [[ActivityTable alloc] init];
    act.delegate = self;
    
    emptyIcon = [UIImage imageNamed:@"emptyDoc"];
    dbIcon = [UIImage imageNamed:@"lildbGrey"];
    batchIcon = [UIImage imageNamed:@"multiNOT"];
    versionNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    oc = [OCRCache sharedInstance];
    pc = [PDFCache sharedInstance];

    refreshControl = [[UIRefreshControl alloc] init];
    batchPFObjects = nil;
    
    fixingErrors = TRUE;

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
-(void)refreshIt
{
    NSLog(@" pull to refresh...");
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
    [self testit];
}


//=============OCR MainVC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    //NSLog(@"mainvc viewDidAppear...");
    [super viewDidAppear:animated];
    _versionLabel.text = [NSString stringWithFormat:@"V %@",versionNumber];
   // [self testit];

   // [self performSegueWithIdentifier:@"templateSegue" sender:@"mainVC"];

    //[self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
}

//=============OCR MainVC=====================================================
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
#endif
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
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
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Template",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"addTemplateSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Edit Template",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"templateSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Clear OCR Cache",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearCacheMenu];
                                                          }];
    UIAlertAction *fourthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Clear PDF Cache",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearPDFCacheMenu];
                                                          }];
    NSString* t = @"Minimum Activity Logging";
    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (mappDelegate.verbose) t = @"Verbose Activity Logging";
    UIAlertAction *fifthAction = [UIAlertAction actionWithTitle:NSLocalizedString(t,nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              mappDelegate.verbose = !mappDelegate.verbose;
                                                          }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:firstAction];
    [alert addAction:secondAction];
    [alert addAction:thirdAction];
    [alert addAction:fourthAction];
    [alert addAction:fifthAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];


} //end menu

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

    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"EXP Table",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Invoice Table",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self performSegueWithIdentifier:@"invoiceSegue" sender:@"mainVC"];
                                                           }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    [alert addAction:firstAction];
    [alert addAction:secondAction];
//    [alert addAction:thirdAction];
//    [alert addAction:fourthAction];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end dbmenu

//=============OCR MainVC=====================================================
// if you click on a batch item, this gets invoked
// TRY CHANGING TITLE FONT SIZE AND COLOR
//   https://stackoverflow.com/questions/31662591/swift-how-to-change-uialertcontrollers-title-color
//   https://exceptionshub.com/uialertcontroller-change-font-color.html
//  This looks the best
//    https://stackoverflow.com/questions/26460706/uialertcontroller-custom-font-size-color
-(void) batchListChoiceMenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Batch Retreival"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Batch Retreival",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert setValue:tatString forKey:@"attributedTitle"];
    
    
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Get EXP records",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              self->stype = @"E";
                                                              [self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Get Invoices",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               self->stype = @"I";
                                                               [self performSegueWithIdentifier:@"expSegue" sender:@"mainVC"];
                                                           }];
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"View/Fix Errors",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              self->fixingErrors = TRUE;
                                                              [self performSegueWithIdentifier:@"errorSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *fourthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"View/Fix Warnings",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              self->fixingErrors = FALSE;
                                                              [self performSegueWithIdentifier:@"errorSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *fifthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Get Report",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self performSegueWithIdentifier:@"batchReportSegue" sender:@"mainVC"];
                                                          }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:firstAction];
    [alert addAction:secondAction];
    [alert addAction:thirdAction];
    [alert addAction:fourthAction];
    [alert addAction:fifthAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
} //end menu


//=============OCR MainVC=====================================================
// Yes/No for cache clear...
-(void) clearCacheMenu
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear OCR Cache? (Cannot be undone!)",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            [self->oc clearHardCore];
                                                        }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO",nil)
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end menu

//=============OCR MainVC=====================================================
// Yes/No for cache clear...
-(void) clearPDFCacheMenu
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear PDF Cache? (Cannot be undone!)",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"YES",nil)
                                                        style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                            [self->pc clearHardCore];
                                                        }];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"NO",nil)
                                                       style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:YES completion:nil];
} //end menu




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
    [nav setHotNot         : NAV_SETTINGS_BUTTON : [UIImage imageNamed:@"gearHOT"]  :
     [UIImage imageNamed:@"gearNOT"] ];
    [nav setLabelText      : NAV_SETTINGS_BUTTON : NSLocalizedString(@"Settings",nil)];
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
    if([[segue identifier] isEqualToString:@"addTemplateSegue"])
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
    }
    else if([[segue identifier] isEqualToString:@"errorSegue"])
    {
        ErrorViewController *vc = (ErrorViewController*)[segue destinationViewController];
        vc.batchData    = sdata;
        vc.fixingErrors = fixingErrors;
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
-(int)countCommas : (NSString *)s
{
    if (s == nil) return 0;
    NSScanner *mainScanner = [NSScanner scannerWithString:s];
    NSString *temp;
    int nc=0;
    while(![mainScanner isAtEnd])
    {
        [mainScanner scanUpToString:@"," intoString:&temp];
        nc++;
        [mainScanner scanString:@"," intoString:nil];
    }
    return nc;
} //end countCommas

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
    NSString *adata = [act getData:row];

    UIImage *ii = emptyIcon;
    cell.badgeLabel.hidden = TRUE;
    //Batch Acdtivity:Batch cell has a badge(errorcount) and custom color...
    //     (NEEDS TO COMPUTE ERRORS< CPU EATER?)
    if ([atype.lowercaseString containsString:@"batch"] && (batchPFObjects != nil))
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
                    int bcount = [self countCommas:pfo[PInv_BatchErrors_key]];
                    int fcount = [self countCommas:pfo[PInv_BatchFixed_key]];;
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
                    bcount = [self countCommas:pfo[PInv_BatchWarnings_key]];
                    fcount = [self countCommas:pfo[PInv_BatchWFixed_key]];;
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
    else //Non-batch activity?
    {
        cell.checkmark.hidden   = TRUE; //No checkmarks!
        cell.badgeLabel.hidden  = TRUE;
        cell.badgeWLabel.hidden = TRUE;
    }
    //...other activity types... invoice, exp, etc...
    if ([atype.lowercaseString containsString:@"invoice"]) ii = dbIcon;
    if ([atype.lowercaseString containsString:@"exp"])     ii = dbIcon;
    //Date -> String, why isn't this in just one call???
    NSDate *activityDate = [act getDate:row];
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy  HH:mmv:SS"];
    NSString *sfd = [formatter stringFromDate:activityDate];
    
    //Fill out Cell UI
    //Top Bold label in the cell...
    cell.topLabel.text    = atype;
    // ..next row, normal text (info etc...)
    cell.bottomLabel.text = adata;
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
    int row = (int)indexPath.row;
    sdata  = [act getData:row];
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
        if (aItems.count == 2)
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
    batchPFObjects = (NSMutableArray *)notification.object;
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
        [self testit];
        return;
        [self performSegueWithIdentifier:@"templateSegue" sender:@"mainVC"];
    }
    if (which == 3) //batch
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
 
   // smartProducts *smartp = [[smartProducts alloc] init];
   // [smartp saveBuiltinKeywordsToParse]; //ONLY CALL THIS ONCE!
   // NSLog(@" smart testit");
    return;
    
//    AppDelegate *mappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//    DropboxTools *dbt = [[DropboxTools alloc] init];
//    [dbt getFolderList : mappDelegate.settings.templateFolder];

    return;
    
    NSDictionary *d    = [self readTxtToJSON:@"hfmpages"];
    OCRDocument *od = [[OCRDocument alloc] init];
    
    NSString *p = @"I. 64";
    [od cleanupPrice:p];
     
    [od setupDocumentAndParseJDON : @"hfmpages" :d :FALSE];
    return;

   // NSDictionary *d    = [self readTxtToJSON:@"beef"];  //hfmpages"];
    NSArray *pr   = [d valueForKey:@"ParsedResults"];
    for (NSDictionary *dd in pr)
    {
        //NSString *parsedText = [dd valueForKey:@"ParsedText"]; //Everything lumped together...
        NSDictionary *to     = [dd valueForKey:@"TextOverlay"];
        NSArray *lines       = [to valueForKey:@"Lines"]; //array of "Words"
        NSLog(@" duh");
        for (NSDictionary *ddd in lines)
        {
            //NSLog(@"duhh: %@",ddd);
            NSArray *words = [ddd valueForKey:@"Words"];
            for (NSDictionary *w in words) //loop over each word
            {
                OCRWord *ow = [[OCRWord alloc] init];
                [ow packFromDictionary:w];
                //NSLog(@" w %@",ow.wordtext);
                [ow dump];
               // [allWords addObject:ow];
            }
        }

    }

    
  //  NSString *gd = @"https://drive.google.com/open?id=1UF9Yh7kRNX8EuSzrLSSdCN00QO9TzVb4";
//    [self downloadPDF:gd];
    // Get the PDF Data from the url in a NSData Object
//    NSData *pdfData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:gd]];
//    NSLog(@" data is %@",pdfData);
   // UIImage *img = [ UIImage imageWithPDFURL:url atSize:CGSizeMake( 60, 60 ) atPage:1 ];

}







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


@end



