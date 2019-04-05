//
//   _____                   __     ______
//  | ____|_ __ _ __ ___  _ _\ \   / / ___|
//  |  _| | '__| '__/ _ \| '__\ \ / / |
//  | |___| |  | | | (_) | |   \ V /| |___
//  |_____|_|  |_|  \___/|_|    \_/  \____|
//
//  ErrorViewController.m
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  1/12  Added E: or W: prefix to errors!
//  2/8   made numericPanelView more compact,
//  The numeric (decimal) keyboard here SUCKS.
//  here is a link about adding a minus and enter key:
//  https://stackoverflow.com/questions/9613109/uikeyboardtypedecimalpad-with-negative-numbers
//  2/12 added field0Value for productname, renamed fieldValue
//  4/5 add rotate 90 degrees
#import "ErrorViewController.h"

@interface ErrorViewController ()

@end

@implementation ErrorViewController


//=============Error VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    bbb = [BatchObject sharedInstance];
    bbb.delegate = self;
    [bbb setParent:self];
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];

    errorList = [[NSMutableArray alloc] init];
    fixedList = [[NSMutableArray alloc] init];
    expList   = [[NSMutableArray alloc] init];
    objectIDs = [[NSMutableArray alloc] init];
    expRecordsByID = [[NSMutableDictionary alloc] init];

    allErrorsInEXPRecord = [[NSMutableArray alloc] init];

    sp = [[smartProducts alloc] init];
    
    //For loading PDF images...
    pc = [PDFCache sharedInstance];
    // For getting page rotation by vendor...
    vv = [Vendors sharedInstance];
    et = [[EXPTable alloc] init];
    it = [[imageTools alloc] init];
    
    xIcon  = [UIImage imageNamed:@"redX"];
    wIcon  = [UIImage imageNamed:@"yellowWarningIcon"];
    okIcon = [UIImage imageNamed:@"bluecheck"];

    et.delegate = self;
    [self initErrorKeys];
    kbUp = FALSE;
    _fixingErrors = TRUE;

    // 4/5 sfx
    _sfx         = [soundFX sharedInstance];

    return self;
} //end initWithCoder

//=============Error VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _table.delegate   = self;
    _table.dataSource = self;
    
    //Scrolling zoomed PDF viewer
    _scrollView.delegate=self;
    _field0Value.delegate = self;
    _field1Value.delegate = self;
    _field2Value.delegate = self;
    _field3Value.delegate = self;

    // 1/19 Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];

} //end viewDidLoad

//=============Error VC=====================================================
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //3/22 multi-customer support...
    [et setTableNameForCurrentCustomer];

    NSLog(@"ERRVC: adata %@",_batchData);
    NSArray* bItems    = [_batchData componentsSeparatedByString:@":"];
    if (bItems.count > 0)
    {
        [spv start : @"Get Batch Errors"];
        batchID = bItems[0];
        [bbb readFromParseByID : batchID];
    }
    [expList removeAllObjects];
    _fixNumberView.hidden = TRUE;
    _scrollView.hidden    = TRUE;
    _rotButton.hidden     = TRUE;
    rotatedCount          = 0;
    [self zoomPDFView : 1];
    
    // Top field: product Name : DO NOT CLEAR!
    _field0Value.clearsOnBeginEditing = NO;
    

} //end viewWillAppear


//=============Error VC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;
} //end loadView

//------(Onboarding)--------------------------------------------------------------
-(void) viewDidLayoutSubviews
{
    //DHS 2/8 moved from loadView
    CGRect rrr = _fixNumberView.frame;
    int xi,yi,xs,ys;
    xs = viewWid;
    xi = 0;
    yi = 65;
    ys = rrr.origin.y - yi;
    _scrollView.frame = CGRectMake(xi, yi, xs, ys);
} //end viewDidLayoutSubviews


//=============Error VC=====================================================
-(void) zoomPDFView : (int) zoomBy
{
    //Zoom up...
    UIView *v = _pdfView;
    int vw = v.bounds.size.width;
    int vh = v.bounds.size.height;
    CGAffineTransform t = v.transform;
    t = CGAffineTransformMakeScale(zoomBy, zoomBy);
    v.transform = t;
    v.center = CGPointMake(vw*zoomBy/2, vh*zoomBy/2);
    _scrollView.contentSize = CGSizeMake(vw*zoomBy, vh*zoomBy);
    [_scrollView setContentOffset:CGPointMake(0,0) animated:NO];
} //end zoomPDFView


//=============Error VC=====================================================
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


//=============Error VC=====================================================
-(void) makeCancelSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 82];
}

//=============Error VC=====================================================
-(void) makeSelectSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 70];
}

//=============Error VC=====================================================
-(void) initErrorKeys
{
    errKeysToCheck= @[   //CANNED
                      PInv_Month_key ,
                      PInv_Category_key ,
                      PInv_Quantity_key ,
                      PInv_Item_key ,
                      PInv_UOM_key ,
                      PInv_Bulk_or_Individual_key ,
                      PInv_Vendor_key ,
                      PInv_TotalPrice_key ,
                      PInv_ProductName_key ,
                      PInv_PricePerUOM_key ,
                      PInv_Processed_key ,
                      PInv_Local_key ,
                      //NOT A STRING PInv_Date_key ,
                      PInv_LineNumber_key ,
                      PInv_InvoiceNumber_key ,
                      PInv_BatchID_key ,
                      PInv_ErrStatus_key ,
                      PInv_PDFFile_key
                      //NOT A STRING PInv_Page_key
                      
                      ];
    errKeysNumeric = @[   //CANNED
                       PInv_Item_key ,  //DHS 3/9
                       PInv_Quantity_key ,
                       PInv_TotalPrice_key ,
                       PInv_PricePerUOM_key
                       ];
    errKeysBinary = @[   //CANNED
                      PInv_Bulk_or_Individual_key ,
                      PInv_Processed_key ,
                      PInv_Local_key
                      ];
} //end initErrorKeys


//=============Error VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}


//=============Error VC=====================================================
- (IBAction)fieldCancelSelect:(id)sender {
    [self makeCancelSound];
    BOOL needToSwap = !kbUp; //2/11
    [self dismissKBIfNeeded];
    [self animateTextField: _field1Value up: NO];
    //Swap sub-panels at bottom?
    if (needToSwap) [self swapViews:FALSE];
}

//=============Error VC=====================================================
- (IBAction)fieldFixSelect:(id)sender
{
    //NSLog(@" fix: new value %@ SAVE TO PARSE...",qText);
    [self makeSelectSound];
    [self dismissKBIfNeeded]; //2/11
    [self textFieldDidEndEditing:_field1Value];
    // save new field to parse...
    BOOL changed = FALSE;
    [spv start:@"Fix Error..."];
    
    if (isNumeric) //Fix q/p/t fields?
    {
        //get stuff first:
        double qd = qText.doubleValue;
        double pd = pText.doubleValue;
        double td = tText.doubleValue;
        td = qd * pd; //Force amount to be correct...
        tText = [sp getDollarsAndCentsString : (float) td]; //Re-format total...
        pText = [sp getDollarsAndCentsString : pText.floatValue]; //Re-format price...
        [et fixPricesInObjectByID : fixingObjectID : iText : qText : pText : tText];
        
        //Look up our EXP object locally...
        EXPObject *exp = [expRecordsByID objectForKey:fixingObjectID];
        exp.productName = iText;   //Fill in our fields from the fix
        exp.quantity    = qText;
        exp.pricePerUOM = pText;
        exp.total       = tText;
        [expRecordsByID setObject:exp forKey:fixingObjectID];
        changed = TRUE;
    }
    
    if (changed) //Need to update batch record?
    {
        if (_fixingErrors)
            [bbb fixError : selectedRow];  //Moves error from batch "errorList" to "fixedList"
        else
            [bbb fixWarning : selectedRow];  //Moves error from batch "errorList" to "fixedList"
        bbb.batchID = batchID;        //BatchID was passed in as part of batchData from parent
        [bbb updateParse];           //annnd save updated batch record
    }
    [self swapViews:FALSE];

    [_table reloadData];

} //end fieldFixSelect


//=============Error VC=====================================================
//  4/5 add rotate 90 degrees
- (IBAction)rotSelect:(id)sender {
    [self makeSelectSound];
    UIImage *ii = _pdfView.image;
    ii = [it rotate90CCW : ii];
    _pdfView.image = ii;
    rotatedCount++;

}


//=============Error VC=====================================================
// 2/11 for cancel/fix button presses
-(void) dismissKBIfNeeded
{
    [self makeCancelSound];
    if (!kbUp) return;
    [_field0Value resignFirstResponder];  //One of these is up, resign all dismisses any keyboard
    [_field1Value resignFirstResponder];
    [_field2Value resignFirstResponder];
    [_field3Value resignFirstResponder];
    kbUp = FALSE; //Needed?
} //end dismissKBIfNeeded

//=============Error VC=====================================================
// 2/8 shows/hides table/backbutton vs. fixnumberview/pdfview
-(void) swapViews : (BOOL) fixingErrors
{
    _table.hidden           = fixingErrors;
    _backButton.hidden      = fixingErrors;
    _fixNumberView.hidden   = !fixingErrors;
    _scrollView.hidden      = !fixingErrors;
    _rotButton.hidden       = !fixingErrors;

} //end swapViews

//=============Error VC=====================================================
// 2/8 wups there were 2 of these!@
-(void) updateUI
{
    NSString *t = @"View / Fix Errors";
    if (!_fixingErrors) t = @"View / Fix Warnings";
    _titleLabel.text = t;
}

//=============Error VC=====================================================
-(void) dismiss
{
    [self makeCancelSound];
    et.parentUp = FALSE; // 2/9 Tell expTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}



#pragma mark - UITableViewDelegate
//=============Error VC=====================================================
// Looks at contents of errorlist, an array of errors. displays fixed/broken status
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    errorCell *cell = (errorCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[errorCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    NSString *errStr = [errorList objectAtIndex:row];
    //NSLog(@" cell %d str %@ fixed %d",row,errStr,[bbb isErrorFixed:errStr]);
    if ([bbb isErrorFixed:errStr])
    {
        NSLog(@" ...FIXED %d",row);
        cell.errIcon.image = okIcon;
        cell.backgroundColor = [UIColor whiteColor];
    } //asdf
    else
    {
        if (_fixingErrors)
        {
            cell.errIcon.image   = xIcon;
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.8 alpha:1];
        }
        else
        {
            cell.errIcon.image   = wIcon;
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:0.4 alpha:1];
        }
    }
    NSString *fullErr = [errorList objectAtIndex:row];
    cell.errorLabel.text = fullErr;

    NSString *pname = @"...";
    //Look for product name in parentheses
    NSArray *eItems    = [fullErr componentsSeparatedByString:@"("];
    if (eItems.count == 2)
    {
        NSArray *e2Items    = [eItems[1] componentsSeparatedByString:@")"];
        if (e2Items.count == 2)
        {
           pname = e2Items[0];
        }
    }
    //Maybe there is a matching EXP object we can find...
    else if (expRecordsByID.count > 0)
    {
        if (row == 3)
            NSLog(@"bing");
        NSString *oid = [self getIDFromErrorString : fullErr];
        //NSLog(@" id from err %@ is %@",fullErr,oid);
        if (oid != nil && oid.length > 0)
        {
            EXPObject *e = [expRecordsByID objectForKey:oid];
            //NSLog(@" object for id %@",oid);
            [e dump];
            if (e != nil)
            {
                pname = e.productName;
            }
        }
    }
    cell.label2.text = pname;
    return cell;
} //end cellForRowAtIndexPath


//=============Error VC=====================================================
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (int)errorList.count;
}

//=============Error VC=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

//=============Error VC=====================================================
// Errors are now E:ErrDesc:ObjID, so there are 3 sub-items! (were 2 before)
-(NSString *) getIDFromErrorString : (NSString *)errString
{
    NSArray *sItems = [errString componentsSeparatedByString:@":"];
    if (sItems.count > 2) //DHS 1/27 format is E : ErrMsg : objectID
    {
        NSString *s = sItems[2]; //If not n/a it is an objectID
        if (![s containsString:@"/"] ) return s;
    }
    return @"";
}

//=============Error VC=====================================================
-(void) loadAllExpObjects
{
    [spv start : @"Load EXP objects"];
    [objectIDs removeAllObjects];
    [expRecordsByID removeAllObjects];
    for (NSString *e in errorList)
    {
        NSLog(@" err %@",e);
        NSString *s = [self getIDFromErrorString : e];
        NSLog(@" .....s %@",s);
        if (s.length > 0) [objectIDs addObject: s];
    }
    [et getObjectsByIDs : objectIDs];
}

//=============Error VC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self makeSelectSound];
    selectedRow        = (int)indexPath.row;
    NSString *allErrs  = [errorList objectAtIndex:selectedRow];
    NSArray *sItems    = [allErrs componentsSeparatedByString:@":"];
    if (sItems.count > 2) //2/28 need 3 fields!
    {
        NSString *errType = sItems[1];
        if ([errType.lowercaseString containsString:@"product"] ||
            [errType.lowercaseString containsString:@"missing"] )
        {    //2/28 bad product / missing fields can't be fixed here...
            [self errorMessage:@"Cannot fix this error" : @"You can only fix numeric product errors in this VC"];
        }
        else
        {
            [spv start : @"Get EXP object"];
            fixingObjectID = sItems[2]; //DHS 1/12 now 3 items in error
            if (![fixingObjectID isEqualToString:@"n/a"]) //Make sure objectID exists...
            {
                //NSLog(@" get EXP object:%@",fixingObjectID);
                [et getObjectByID:fixingObjectID]; //Delegate callback updates ui...
                [spv stop];
            }
        }
    }
} //end didSelectRowAtIndexPath


#pragma mark - batchObjectDelegate

//=============<batchObjectDelegate>=====================================================
- (void)didReadBatchByID : (NSString *)oid
{
    if (_fixingErrors) //Get copy of whichever array we need
        errorList = [NSMutableArray arrayWithArray:[bbb getErrors]];
    else
        errorList = [NSMutableArray arrayWithArray:[bbb getWarnings]];
    //NSLog(@" ok batch read %@:%@",oid,errorList);
    [spv stop];
    [self loadAllExpObjects];
    [_table reloadData];
    [self updateUI];
}

//=============<batchObjectDelegate>=====================================================
- (void)errorReadingBatchByID : (NSString *)err
{
    
    
}

//=============<batchObjectDelegate>=====================================================
- (void)didUpdateBatchToParse
{
    NSLog(@" //ok batch didUpdateBatchToParse");

}




//=============Error VC=====================================================
// Opens up a subpanel which will vary based on the error,
//    also loads up the scanned image if possible...
// Quantity / Price / Amount Error(s) use a 3-field numeric UI
//
-(void) setupPanelForError : (NSString*) key
{
    NSLog(@"show fixit view...");
    [self swapViews : TRUE];
    //Show error fixing view...
    _table.hidden         = TRUE;
    _backButton.hidden    = TRUE;
    _fixNumberView.hidden = FALSE;
    _pdfView.hidden       = FALSE;
    _rotButton.hidden     = FALSE;

    fixingObjectKey = key;
    isNumeric = [errKeysNumeric containsObject:key];
    _numericPanelView.hidden = !isNumeric;
    _field0Value.text = pfoWork[PInv_ProductName_key];
    
    vendorName = [bbb getVendor];
    
    NSString *pdfName = pfoWork[PInv_PDFFile_key];
    NSString *pdfPage = pfoWork[PInv_Page_key];
    errorPage = pdfPage.intValue;
    //This assumes PDF is in cache... but what if it's NOT???
    //int dog = 0;
    if ([pc imageExistsByID : pdfName : errorPage+1])
    {
        NSLog(@" ...cache HIT %@",pdfName);
        UIImage *ii = nil;
        ii = [pc getImageByID : pdfName : errorPage+1];
        [self finishSettingPDFImage : ii];
    }
    else //Cache miss? get PDF directly from dropbox...
    {
        [spv start: @"Download PDF..."];
        NSLog(@" ...cache MISS: downloading %@",pdfName);
        [dbt downloadImages:pdfName];
    }
    [_field0Value setKeyboardType:UIKeyboardTypeDefault];

    if (isNumeric) //Is this a numeric field?
    {
        NSString *q = pfoWork[PInv_Quantity_key];
        if (q.length < 1) q = @"$ERR";
        [_field1Value setKeyboardType:UIKeyboardTypeDecimalPad];
        [_field1Value setText : q];
        [_field2Value setKeyboardType:UIKeyboardTypeDecimalPad];
        NSString *p = pfoWork[PInv_PricePerUOM_key];
        if (p.length < 1) p = @"$ERR";
        [_field2Value setText : p];
        [_field3Value setKeyboardType:UIKeyboardTypeDecimalPad];
        NSString *t = pfoWork[PInv_TotalPrice_key];
        if (t.length < 1) t = @"$ERR";
        [_field3Value setText : t];
    }
    else{ // Characters and numbers?
        [_field1Value setKeyboardType:UIKeyboardTypeDefault];
    }
} //end setupPanelForError

//=============Error VC=====================================================
-(void) finishSettingPDFImage : (UIImage *)ii
{
    //Does this vendor usually have XY flipped scans?
    NSString *rot = [vv getRotationByVendorName:vendorName];
    if ([rot isEqualToString:@"-90"]) ii = [it rotate90CCW : ii];
    // If user has rotated image earlier, rotate image to match their preference
    for (int i=0;i<rotatedCount;i++) ii = [it rotate90CCW : ii];
    _pdfView.image = ii;
    [self zoomPDFView : 3];

} //end finishSettingPDFImage



#pragma mark - DropboxToolsDelegate
//=============<DropboxToolsDelegate>=====================================================
// returning from a PDF fetch...
- (void)didDownloadImages
{
    [spv stop];
    if (errorPage < 0 || errorPage >= dbt.batchImages.count) return;
    UIImage *ii = dbt.batchImages[errorPage];
    [self finishSettingPDFImage:ii];
}

//=============<EXPTableDelegate>=====================================================
- (void)errorDownloadingImages : (NSString *)s
{
    [spv stop];
    NSLog(@" ERROR! %@",s); //2/8 MAKE THIS AN ERROR POPUP?
}


#pragma mark - EXPTableDelegate

//=============<EXPTableDelegate>=====================================================
//Returning dictionary of EXP objects keyed by id's
- (void)didGetObjectsByIds : (NSMutableDictionary *)d
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });

    //NSLog(@" OK exp objectsBYid %@",d);
    expRecordsByID = d;
    [_table reloadData];
}


//=============<EXPTableDelegate>=====================================================
- (void)didReadEXPObjectByID :(EXPObject *)e  : (PFObject*)pfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });
    pfoWork = pfo;
    [allErrorsInEXPRecord removeAllObjects];

    //What about stuff that isn't in this set, like page or date?
    // there is no error marking there yet
    for (NSString * key in errKeysToCheck)
    {
        //Check for a flagged error in a field...
        if ([[pfo objectForKey:key] isEqualToString:@"$ERR"])
        {
            NSLog(@" hit err on %@",key);
            [allErrorsInEXPRecord addObject:key];
        }
    }
    NSString *errStatus = e.errStatus.lowercaseString;
    if ([errStatus containsString:@"zero"] || [errStatus containsString:@"bad"] ) //Numeric field errors?
        [allErrorsInEXPRecord addObject:PInv_TotalPrice_key];
    //Did we get any errors?
    if (allErrorsInEXPRecord.count > 0)
    {
        [self setupPanelForError : allErrorsInEXPRecord[0]]; //0th item in list of keys <-- DBKeys.h
    }
    //Controls need to be set up for these fields, what if there are over 3 errors?
    //Maybe show only 3 at a time?
    
    //for ()
}


//=============<EXPTableDelegate>=====================================================
- (void)didFixPricesInObjectByID : (NSString *)oid
{
    [spv stop];
    NSLog(@" OK: saved qpt for object %@ , delete from error list",oid);
    //1/23 WRONG![errorList removeObjectAtIndex:selectedRow];
    [_table reloadData];


} //end didFixPricesInObjectByID

//=============<EXPTableDelegate>=====================================================
- (void)errorFixingPricesInObjectByID : (NSString *)err
{
    [spv stop];
}


#pragma mark - UITextFieldDelegate

//==========<UITextFieldDelegate Helper>================================================================
- (void) animateTextField: (UITextField*) textField up: (BOOL) up
{
    if (up == kbUp) return;
    const int movementDistance = 300; // tweak as needed
    const float movementDuration = 0.3f; // tweak as needed
    
    int movement = (up ? -movementDistance : movementDistance);
    
    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
    kbUp = up;

} //end animateTextField

//==========<UITextFieldDelegate>================================================================
-(void) loadFields : (int) tag : (UITextField*) tfield
{
    iText = _field0Value.text;
    qText = _field1Value.text;
    pText = _field2Value.text;
    tText = _field3Value.text;
} //end loadFields

//==========<UITextFieldDelegate>================================================================
- (IBAction)textChanged:(id)sender
{
    UITextField *tt = (UITextField*)sender;
    int tag = (int)tt.tag;
    [self loadFields:tag:tt];
} //end commentChanged

//==========<UITextFieldDelegate>================================================================
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{

    return YES;
}



//==========<UITextFieldDelegate>================================================================
//NEVER GETS CALLED?
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    NSLog(@" shdclear");
    if (textField == _field0Value) return NO;
    return YES;
}
//==========<UITextFieldDelegate>================================================================
// It is important for you to hide the keyboard
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@" shdreturn");
    //NSLog(@" textFieldShouldReturn");
    [textField resignFirstResponder];
    return YES;
}


//==========<UITextFieldDelegate>================================================================
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self animateTextField: textField up: YES];
    if (textField != _field0Value) [textField setText:@""]; //DHS 2/12
} //end textFieldDidBeginEditing


//==========<UITextFieldDelegate>================================================================
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self animateTextField: textField up: NO];
    [textField resignFirstResponder];
    int tag = (int)textField.tag;
    [self loadFields:tag:textField];
} //end textFieldDidEndEditing






@end
