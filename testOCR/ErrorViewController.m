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
    return self;
}

//=============Error VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _table.delegate   = self;
    _table.dataSource = self;
    
    //Scrolling zoomed PDF viewer
    _scrollView.delegate=self;

    _fieldValue.delegate = self;
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
    NSLog(@"ERRVC: adata %@",_batchData);
    NSArray* bItems    = [_batchData componentsSeparatedByString:@":"];
    if (bItems.count > 0)
    {
        [spv start : @"Read batch"];
        batchID = bItems[0];
        [bbb readFromParseByID : batchID];
    }
    [expList removeAllObjects];
    _fixNumberView.hidden = TRUE;

    
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
    
    int xi,yi,xs,ys;
    xs = viewWid;
    ys = xs;
    xi = viewW2 - xs/2;
    yi = 60;
    _scrollView.frame = CGRectMake(xi, yi, xs, ys);

    [self zoomPDFView : 1];
    
//    yi+= ys+10;
//    xs = viewWid * 0.95;
//    ys = 200; //Too Tall?
//    xi = viewW2 - xs/2;
//    _outputLabel.frame = CGRectMake(xi, yi, xs, ys);
//    _outputLabel.text  = @"...";
} //end loadView

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
                      PInv_Batch_key ,
                      PInv_ErrStatus_key ,
                      PInv_PDFFile_key
                      //NOT A STRING PInv_Page_key
                      
                      ];
    errKeysNumeric = @[   //CANNED
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
    //Hide sub-panel for fixing fields... table should show up
    _fixNumberView.hidden = TRUE;

}

//=============Error VC=====================================================
- (IBAction)fieldFixSelect:(id)sender
{
    NSLog(@" fix: new value %@ SAVE TO PARSE...",qText);
    [self textFieldDidEndEditing:_fieldValue];
    // save new field to parse...
    BOOL changed = FALSE;
    
    if (isNumeric) //Fix q/p/t fields?
    {
        //get stuff first:
        double qd = qText.doubleValue;
        double pd = pText.doubleValue;
        double td = tText.doubleValue;
        td = qd * pd; //Force amount to be correct...
        tText = [sp getDollarsAndCentsString : (float) td]; //Re-format total...
        pText = [sp getDollarsAndCentsString : pText.floatValue]; //Re-format price...
        [et fixPricesInObjectByID : fixingObjectID : qText : pText : tText];
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
    _fixNumberView.hidden = TRUE;
    [_table reloadData];

} //end fieldFixSelect


//=============Error VC=====================================================
-(void) UpdateUI
{
    NSString *t = @"View / Fix Errors";
    if (!_fixingErrors) t = @"View / Fix Warnings";
    _titleLabel.text = t;
}


//=============Error VC=====================================================
-(void) updateUI
{
}


//=============Error VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}



#pragma mark - UITableViewDelegate
//=============Error VC=====================================================
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
    if ([bbb isErrorFixed:errStr])
    {
        cell.errIcon.image = okIcon;
        cell.backgroundColor = [UIColor whiteColor];
    } //asdf
    else
    {
        if (_fixingErrors)
        {
            cell.errIcon.image   = xIcon;
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:0.4 alpha:1];
        }
        else
        {
            cell.errIcon.image   = wIcon;
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:0.4 alpha:1];
        }
    }
    NSString *fullErr = [errorList objectAtIndex:row];
    cell.errorLabel.text = fullErr;
    NSLog(@" cell %d %@",row,fullErr);

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
        NSString *oid = [self getIDFromErrorString : fullErr];
        if (oid != nil && oid.length > 0)
        {
            EXPObject *e = [expRecordsByID objectForKey:oid];
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
    NSLog(@"ecount %d",(int)errorList.count);
    return (int)errorList.count;
}

//=============Error VC=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 40;
}

//=============Error VC=====================================================
// Errors are now E:ErrDesc:ObjID, so there are 3 sub-items! (were 2 before)
-(NSString *) getIDFromErrorString : (NSString *)errString
{
    NSArray *sItems = [errString componentsSeparatedByString:@":"];
    if (sItems.count > 1)
    {
        NSString *s = sItems[2]; //DHS 1/12
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
        NSString *s = [self getIDFromErrorString : e];
        if (s.length > 0) [objectIDs addObject: s];
    }
    [et getObjectsByIDs : objectIDs];
}

//=============Error VC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    selectedRow        = (int)indexPath.row;
    NSString *allErrs  = [errorList objectAtIndex:selectedRow];
    NSArray *sItems    = [allErrs componentsSeparatedByString:@":"];
    if (sItems.count > 1)
    {
        [spv start : @"Get EXP object"];
        fixingObjectID = sItems[2]; //DHS 1/12 now 3 items in error
        NSLog(@" duh %@",fixingObjectID);
        [et getObjectByID:fixingObjectID];
    }
    //EXPObject *e = [et.expos objectAtIndex:selectedRow];
    //[self performSegueWithIdentifier:@"expDetailSegue" sender:e];
    
} //end didSelectRowAtIndexPath


#pragma mark - batchObjectDelegate

//=============<batchObjectDelegate>=====================================================
- (void)didReadBatchByID : (NSString *)oid
{
    if (_fixingErrors) //Get copy of whichever array we need
        errorList = [NSMutableArray arrayWithArray:[bbb getErrors]];
    else
        errorList = [NSMutableArray arrayWithArray:[bbb getWarnings]];
    NSLog(@" ok batch read %@:%@",oid,errorList);
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
    NSLog(@" ok batch didUpdateBatchToParse");

}




//=============Error VC=====================================================
// Opens up a subpanel which will vary based on the error,
//    also loads up the scanned image if possible...
// Quantity / Price / Amount Error(s) use a 3-field numeric UI
//
-(void) setupPanelForError : (NSString*) key
{
    NSLog(@"show fixit view...");
    //Show error fixing view...
    _fixNumberView.hidden = FALSE;
    fixingObjectKey = key;
    isNumeric = [errKeysNumeric containsObject:key];
    _numericPanelView.hidden = !isNumeric;
    _productName.text = pfoWork[PInv_ProductName_key];
    
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
        NSLog(@" ...cache MISS: downloading %@",pdfName);
        [dbt downloadImages:pdfName];
    }
    if (isNumeric) //Is this a numeric field?
    {
        NSString *q = pfoWork[PInv_Quantity_key];
        if (q.length < 1) q = @"$ERR";
        [_fieldValue setKeyboardType:UIKeyboardTypeDecimalPad];
        [_fieldValue setText : q];
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
        [_fieldValue setKeyboardType:UIKeyboardTypeDefault];
    }
} //end setupPanelForError

//=============Error VC=====================================================
-(void) finishSettingPDFImage : (UIImage *)ii
{
    //Does this vendor usually have XY flipped scans?
    NSString *rot = [vv getRotationByVendorName:vendorName];
    if ([rot isEqualToString:@"-90"]) ii = [it rotate90CCW : ii];
    _pdfView.image = ii;
    [self zoomPDFView : 4];

} //end finishSettingPDFImage



#pragma mark - DropboxToolsDelegate
//=============<DropboxToolsDelegate>=====================================================
// returning from a PDF fetch...
- (void)didDownloadImages
{
    if (errorPage < 0 || errorPage >= dbt.batchImages.count) return;
    UIImage *ii = dbt.batchImages[errorPage];
    [self finishSettingPDFImage:ii];
  //  @property (nonatomic , strong) NSMutableArray* batchImages;
   //asdf
}


#pragma mark - EXPTableDelegate

//=============<EXPTableDelegate>=====================================================
//Returning dictionary of EXP objects keyed by id's
- (void)didGetObjectsByIds : (NSMutableDictionary *)d
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });

    NSLog(@" OK exp objectsBYid %@",d);
    expRecordsByID = d;
    [_table reloadData];
}


//=============<EXPTableDelegate>=====================================================
- (void)didReadEXPObjectByID :(EXPObject *)e  : (PFObject*)pfo
{
    NSLog(@" e is %@",e);
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


//=============<EXPTableDelegate>==================================asdf===================
- (void)didFixPricesInObjectByID : (NSString *)oid
{
    NSLog(@" OK: saved qpt for object %@ , delete from error list",oid);
    [errorList removeObjectAtIndex:selectedRow];
    [_table reloadData];


} //end didFixPricesInObjectByID


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
//    if (tag == 101)
        qText = _fieldValue.text;
//    else if (tag == 102)
        pText = _field2Value.text;
//    else if (tag == 103)
        tText = _field3Value.text;
    NSLog(@" qpt %@ x %@ = %@",qText,pText,tText);

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
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    NSLog(@" shdclear");
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
    NSLog(@" begedit");
    [self animateTextField: textField up: YES];
    [textField setText:@""];
} //end textFieldDidBeginEditing


//==========<UITextFieldDelegate>================================================================
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSLog(@" endedit");
    [self animateTextField: textField up: NO];
    [textField resignFirstResponder];
    int tag = (int)textField.tag;
    [self loadFields:tag:textField];
} //end textFieldDidEndEditing







@end
