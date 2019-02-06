//
//  __     ___                ____            _             _ _
//  \ \   / (_) _____      __/ ___|___  _ __ | |_ _ __ ___ | | | ___ _ __
//   \ \ / /| |/ _ \ \ /\ / / |   / _ \| '_ \| __| '__/ _ \| | |/ _ \ '__|
//    \ V / | |  __/\ V  V /| |__| (_) | | | | |_| | | (_) | | |  __/ |
//     \_/  |_|\___| \_/\_/  \____\___/|_| |_|\__|_|  \___/|_|_|\___|_|
//
//  ViewController.m
//  testOCR
//
//  Created by Dave Scruton on 12/3/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  CSV Columns for Exp Sheet Example.xlsx
// Category,Month,Item,Quantity, Unit of Measure, Bulk/Individual Pack , Vendor Name, Total Price, Price/UOM , Processed, Local, Invoice Date, Line#
// Here's more info:
//   https://ocr.space/ocrapi/confirmation
//   https://github.com/A9T9/OCR.Space-OCR-API-Code-Snippets/blob/master/ocrapi.m
// OUCH: deskew!
//   https://stackoverflow.com/questions/48792790/calculating-skew-angle-using-opencv-in-ios
//  needs openCV?
//  https://www.codeproject.com/Articles/104248/%2fArticles%2f104248%2fDetect-image-skew-angle-and-deskew-image
//  simple deskew?
//  https://stackoverflow.com/questions/41546181/how-to-deskew-a-scanned-text-page-with-imagemagick
//
//  In Adjust mode, zoom in??
//  1/13 Added more detail to activity outputs...
#import "EditTemplateVC.h"

 

@implementation EditTemplateVC

//=============OCR VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;

    od = [[OCRDocument alloc] init];
    ot = [[OCRTemplate alloc] init];
    ot.delegate = self;  //1/16 WHY WASN'T THIS HERE!?
    
    oto = [OCRTopObject sharedInstance];
    oto.delegate = self;

    act = [[ActivityTable alloc] init];
    act.delegate = self;
    
    arrowLHStepSize = 10;
    arrowRHStepSize = 10;
    editing = adjusting = FALSE;
    
    docnum = 4;
    OCR_mode = 1;  //1 = use stubbed OCR, 2 = fetch new OCR from server

    invoiceDate = [[NSDate alloc] init];
    rowItems    = [[NSMutableArray alloc] init];
    EXPDump     = [[NSMutableArray alloc] init];
    smartp      = [[smartProducts alloc] init];
    fastIcon    = [UIImage imageNamed:@"ssd_hare"];
    slowIcon    = [UIImage imageNamed:@"ssd_tortoise"];
    
    it = [[invoiceTable alloc] init];
    it.delegate = self;
    et = [[EXPTable alloc] init];
    et.delegate = self;
    
    clugey = 30; //Magnifying glass image pixel offsets!
    clugex = 84;
    
    _incomingOCRText = @"";
    
    smartCount = 0;
    
    _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

    return self;
}



//=============OCR VC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;
}

//=============OCR VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //parse test
    
    if (_incomingOCRText.length < 1) //Not being invoked by AddTemplateVC->CheckTemplateVC?
    {
        if (OCR_mode == 1) //Stubbed mode vs live OCR
        {
            [self loadStubbedOCRData];
            [ot readFromParse:supplierName]; //Unpacks template and loads it from DB
            //XMAS STUB [ot loadTemplatesFromDisk:supplierName];
        }
        

    }
        
    
    _LHArrowView.hidden = TRUE;
    _RHArrowView.hidden = TRUE;
    pageRect = _inputImage.frame;
    
    CGRect magFrame = CGRectMake(0,0,240,120); //This goes with 2*radius,radius in magview frame setup!
    //    CGRect magFrame = CGRectMake(0,0,120,120);
    magView = [[MagnifierView alloc] initWithFrame:magFrame];
    [self.view addSubview:magView];
    magView.gotiPad       = FALSE; //_gotiPad; //DHS 5/8
    magView.viewToMagnify = _inputImage;
    magView.hidden        = TRUE;
    
    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    int xs,ys,xi,yi;
    xs = ys = 64;
    xi = viewW2 - xs/2;
    yi = viewH2 - ys/2;
    spinner.frame = CGRectMake(xi, yi, xs, ys);
    [self.view addSubview:spinner];
    spinner.hidden = TRUE;
    
    //Canned starting stuff...
    //    supplierName = @"HFM";
    //    selectFnameForTemplate  = @"hfm90.jpg";
    //    selectFname  = @"hfm.jpg";
    //    [_inputImage setImage:[UIImage imageNamed:selectFnameForTemplate]];
    [self scaleImageViewToFitDocument];
    
}

//=============OCR VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}


//=============OCR VC=====================================================
-(void) scaleImageViewToFitDocument
{
    int iwid = _inputImage.image.size.width;
    int ihit = _inputImage.image.size.height;
    int xi,yi,xs,ys;
    xi = 0;
    yi = 90;
    xs = viewWid;
    ys = (int)((double)xs * (double)ihit / (double)iwid);
    CGRect rr = CGRectMake(xi, yi, xs, ys);
    _inputImage.frame = rr;
    _selectOverlayView.frame = rr;
    _overlayView.frame = rr;
}


//=============OCR VC=====================================================
// NOTE this gets called WHENEVER select box moves!!!
- (void)viewWillLayoutSubviews {
    //Make sure screen has settled before adding overlays!
    [self refreshOCRBoxes];
    if (selectBox == nil) //Add selection box...
    {
        selectDocRect = CGRectMake(0, 0, 100, 100); //
        selectBox = [[UIView alloc] initWithFrame:[self documentToScreenRect:selectDocRect]];
        selectBox.backgroundColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.0 alpha:0.5];
        [_selectOverlayView addSubview:selectBox];
        selectBox.hidden = TRUE;
        
    }
    
    
}

//=============OCR VC=====================================================
-(void) stopMagView
{
    magView.hidden = TRUE;
}

//=============OCR VC=====================================================
-(void) setupMagView : (int) x : (int) y
{
    //WHY DO I NEED the xy cluge!??
    CGPoint tl2 = CGPointMake(x + clugex , y + clugey ); ///WHY O WHY??  for 120x120, radius,radius
    magView.hidden     = FALSE;
    
    BOOL below = FALSE;
    BOOL left  = TRUE;
    int fry = _inputImage.frame.size.height;
    int frx = _inputImage.frame.size.width;
    if (y < fry/4) below = TRUE;
    if (x < frx/2) left  = FALSE;
    [magView setTouchPoint:tl2:below:left];
    
    //    magView.touchPoint = tl2;
    [_inputImage setNeedsDisplay];
    [magView setNeedsDisplay];
} //end setupMagView

//=============OCR VC=====================================================
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    dragging = YES;
    //    CGPoint center;
    //    int i,tx,ty,xoff,yoff,xytoler;
    UITouch *touch  = [[event allTouches] anyObject];
    touchLocation   = [touch locationInView:_inputImage];
    touchX          = touchLocation.x;
    touchY          = touchLocation.y;
    touchDocX = [self screenToDocumentX : touchX ];
    touchDocY = [self screenToDocumentY : touchY ];
    if (!adjusting)
    {
        adjustSelect = [ot hitField:touchDocX :touchDocY];
        if (adjustSelect != -1 && !editing && !adjusting)
        {
            [self promptForAdjust:self];
        }
    }
}

//=============OCR VC=====================================================
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    touchLocation = [touch locationInView:_inputImage];
    //int   xi,yi;
    touchX = touchLocation.x;
    touchY = touchLocation.y;
    touchDocX = [self screenToDocumentX : touchX ];
    touchDocY = [self screenToDocumentY : touchY ];
    if (adjusting || editing)
    {
        [self dragSelectBox:touchX :touchY];
    }
    
}

//==========createVC=========================================================================
- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    dragging = NO;
    //NSLog(@" touchEnded");
} //end touchesEnded

//=============OCR VC=====================================================
-(void) clearOverlay
{
    NSArray *viewsToRemove = [_overlayView subviews];
    for (UIView*v in viewsToRemove) [v removeFromSuperview];
    
}

//=============OCR VC=====================================================
// Clears and adds OCR boxes as defined in the OCRTemplate
-(void) refreshOCRBoxes
{
    //Clear overlay...
    [self clearOverlay];
    //NSLog(@" ot boxcount %d",[ot getBoxCount]);
    for (int i=0;i<[ot getBoxCount];i++)
    {
        CGRect rr = [ot getBoxRect:i]; //In document coords
        //NSLog(@" docbox[%d] %@",i,NSStringFromCGRect(rr));
        
        int xi = [self documentToScreenX:rr.origin.x];
        int yi = [self documentToScreenY:rr.origin.y];
        int xs = (int)((double)rr.size.width  / docXConv);
        int ys = (int)((double)rr.size.height / docYConv);
        //WHY O WHY do I need the 90 offset when drawing these views?
        //  it corresponds to the fact that overlayview is 90 pixels from screen top,
        //   but WHY???
        //selectoverlayview is in the same place but the select box isn't drawn off by 90!
        UIView *v =  [[UIView alloc] initWithFrame:CGRectMake(xi, yi- 90, xs, ys)];
        //NSLog(@" selbox[%d] %@",i,NSStringFromCGRect(v.frame));
        NSString *fieldName = [ot getBoxFieldName : i];
        if ([fieldName isEqualToString:INVOICE_IGNORE_FIELD])
            v.backgroundColor = [UIColor colorWithRed:0.8 green:0.9 blue:0.0 alpha:0.6]; //Yellowish
        else if (
                 [fieldName isEqualToString:INVOICE_NUMBER_FIELD] ||
                 [fieldName isEqualToString:INVOICE_DATE_FIELD] ||
                 [fieldName isEqualToString:INVOICE_CUSTOMER_FIELD] ||
                 [fieldName isEqualToString:INVOICE_SUPPLIER_FIELD] ||
                 [fieldName isEqualToString:INVOICE_HEADER_FIELD] ||
                 [fieldName isEqualToString:INVOICE_TOTAL_FIELD]
                 )
            v.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.8 alpha:0.6];  //Cyan
        else
            v.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:0.6];  //Grey
        [_overlayView addSubview:v];
    }
} //end refreshOCRBoxes



//=============OCR VC=====================================================
-(void) loadStubbedOCRDataLite
{
    [self getStubbedStrings];
    [_inputImage setImage:[UIImage imageNamed:selectFnameForTemplate]];
    [self scaleImageViewToFitDocument];

} //end loadStubbedOCRDataLite

//=============OCR VC=====================================================
//DHS 1/17
-(void) getStubbedStrings
{
    if (docnum == 1)
    {
        stubbedDocName = @"hfm";
        supplierName   = @"HFM";
        selectFname    = @"hfm.jpg";
        selectFnameForTemplate = @"hfm90.jpg"; //This should be rotated for user
        docFlipped90 = TRUE;
    }
    if (docnum == 2)
    {
        stubbedDocName = @"beef";
        supplierName   = @"Hawaii Beef Producers";
        selectFname    = @"hawaiiBeefInvoice.jpg";
        selectFnameForTemplate = @"hawaiiBeefInvoice.jpg";  //This should be rotated for user
        docFlipped90 = FALSE;
    }
    if (docnum == 3)
    {
        stubbedDocName = @"gordon";
        supplierName   = @"Gordon";
        selectFname    = @"gordon";
        selectFnameForTemplate = @"gordon.png";  //This should be rotated for user
        docFlipped90 = FALSE;
    }
    if (docnum == 4)
    {
        stubbedDocName = @"greco";
        supplierName   = @"Greco";
        selectFname    = @"greco";
        selectFnameForTemplate = @"grecoShrunk3.png";  //This should be rotated for user
        docFlipped90 = FALSE;
    }

}

//=============OCR VC=====================================================
-(void) loadStubbedOCRData
{
    NSLog(@" Load stubbed OCR data...");
    [self getStubbedStrings];
    [_inputImage setImage:[UIImage imageNamed:selectFnameForTemplate]];
    [self scaleImageViewToFitDocument];

    NSDictionary *d = [self readTxtToJSON:stubbedDocName];
    if (d != nil)
    {
        [od setupDocumentAndParseJDON : selectFnameForTemplate : d : docFlipped90];
        
        tlRect = [od getTLRect];
        trRect = [od getTRRect];
        //NOTE: BL rect may be same as TLrect because it looks for leftmost AND bottommost!
        blRect = [od getBLRect];
        brRect = [od getBRRect];
        docRect = [od getDocRect]; //Get min/max limits of printed text
        [ot setOriginalRects : tlRect : trRect];
        ot.supplierName = supplierName; //Pass along supplier name to template
        ot.pdfFile      = selectFnameForTemplate;
        
        //Set unit scaling
        [od computeScaling : tlRect : trRect];
        
        CGRect r = _inputImage.frame;
        //Screen -> Document conversion
        //MUST HAVE image loaded correctly at this point!
        docXConv = (double)_inputImage.image.size.width  / (double)r.size.width;
        docYConv = (double)_inputImage.image.size.height / (double)r.size.height;

    }
} //End loadStubbedOCRData


//=============OCR VC=====================================================
- (IBAction)testSelect:(id)sender {
    //[self testEmail:sender];
    //return;
    
    //NSDate *date = [od isItADate:@"duhhhhhhhh"];
    //NSDate *date2 = [od isItADate:@"12/24/18"];
    
    
    //imageTools *it = [[imageTools alloc] init];
    //[it findCorners:_inputImage.image];
    //[it deskew:[UIImage imageNamed:@"cocacola.jpg"]];
    // [it deskew:[UIImage imageNamed:@"hawaiiBeefInvoice.jpg"]];
    //NSLog(@" duh just deskewed");
    //OCR_mode = 1;
    if (OCR_mode == 1)
    {
        //CLUGE: myst have a batch ID for EXP records now!
        AppDelegate *eappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        eappDelegate.batchID = @"STUBBED";
        oto.batchID = @"STUBBED";
        [self loadStubbedOCRData]; //asdf
        oto.imageFileName = selectFname; //selectFnameForTemplate;
        oto.vendor        = supplierName; //TEST
        NSDictionary *d = [self readTxtToJSON:stubbedDocName]; //TEST: only works for beef invoice!
        [oto setupTestDocumentJSON:d];
        UIImage *imageToOCR = [UIImage imageNamed:selectFnameForTemplate];
        CGRect r = CGRectMake(0, 0, imageToOCR.size.width, imageToOCR.size.height);
        //We only need the frame now!
        [oto setupDocumentFrameAndParseJSON : r];
        oto.totalLines = 0; //Stubbed call... this is for keeping track of multiple page
        [oto applyTemplate : ot : 1];
        [oto writeEXPToParse : 0]; //Note 2nd arg is page!
        NSString *OCR_Results_Dump = [oto dumpResults];
        [self alertMessage:@"Invoice Dump" :OCR_Results_Dump];
    }
    else{   //Better make sure template is set up here!!!
        [self loadStubbedOCRDataLite]; //asdf
        oto.imageFileName = selectFnameForTemplate;
        oto.ot = ot; //Hand template down to oto

        [oto performOCROnImage : selectFnameForTemplate : [UIImage imageNamed:selectFnameForTemplate]];
    }
    
    //    [self callOCRSpace : @"hawaiiBeefInvoice.jpg"];
    //[self callOCRSpace : @"hfm.jpg"];
}

//======(Hue-Do-Ku allColorPacks)==========================================
- (IBAction)testEmail:(id)sender
{
    spinner.hidden = FALSE;
    [spinner startAnimating];
    [et readFromParseAsStrings : TRUE : @"HFM" : @"*"];
    
}



//=============(OCRTopObject)=====================================================
// for testing only
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

//=============OCR VC=====================================================
-(NSDictionary*) getJSON : (NSString *)s
{
    NSData *jsonData = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&e];
    return dict;
}

//=============OCR VC=====================================================
-(void) clearFields
{
    [ot clearFields];
    // ...save to PInv_ActivityType_key and PInv_ActivityData keys...
    [act saveActivityToParse:@"Clear Template" : supplierName];
    [ot saveToParse:self->supplierName];
    // Set limits where text was found at top / left / right,
    //  used for re-scaling if invoice was shrunk or whatever
    [ot setOriginalRects:tlRect :trRect];
    [self refreshOCRBoxes];
}



//=============OCR VC=====================================================
-(void) addNewField : (NSString*) ftype
{
    //Multiple columns are desired, other types of fields are one-only!
    if (![ftype isEqualToString:INVOICE_COLUMN_FIELD] &&
        ![ftype isEqualToString:INVOICE_IGNORE_FIELD] &&
        [ot gotFieldAlready:ftype])
    {
        [self alertMessage:@"Field in Use" :@"This field is already used."];
        return;
    }
    _LHArrowView.hidden = FALSE;
    _RHArrowView.hidden = FALSE;
    _instructionsLabel.text = @"Move/Resize box with arrows";
    fieldName = ftype;
    [self getShortFieldName];
    editing = TRUE;
    lhArrowsFast = rhArrowsFast = TRUE;
    arrowLHStepSize = 10;
    arrowRHStepSize = 10;
    [self updateCenterArrowButtons];
    [self moveOrResizeSelectBox : -1000 : -1000 : 0 : 0];
    [self resetSelectBox];
    // Change bottom button so user knows they can cancel...
    [_addFieldButton setTitle:@"Cancel" forState:UIControlStateNormal];
    
} //end addNewField

//=============OCR VC=====================================================
-(void) adjustField
{
    _LHArrowView.hidden = FALSE;
    _RHArrowView.hidden = FALSE;
    _instructionsLabel.text = @"Adjust box with arrows";
    fieldName = [ot getBoxFieldName:adjustSelect];
    [self getShortFieldName];
    adjusting = TRUE;
    lhArrowsFast = rhArrowsFast = FALSE;
    arrowLHStepSize = 1;
    arrowRHStepSize = 1;
    [self updateCenterArrowButtons];
    [self updateCenterArrowButtons];
    
    CGRect rr = [ot getBoxRect:adjustSelect]; //This is in document coords!
    [ot dumpBox:adjustSelect];
    int xi = [self documentToScreenX:rr.origin.x];
    int yi = [self documentToScreenY:rr.origin.y];
    yi -= 90; //Stoopid 90 again!
    int xs = [self documentToScreenW:rr.size.width];
    int ys = [self documentToScreenH:rr.size.height];
    selectBox.frame =  CGRectMake(xi, yi, xs, ys);
    selectBox.hidden = FALSE;
    
    //set up magview
    [self setupMagView : xi : yi];
    
    // Change bottom button so user knows they can cancel...
    [_addFieldButton setTitle:@"Cancel" forState:UIControlStateNormal];
    
    
}

//=============OCR VC=====================================================
// Internal stuff...
-(void) getShortFieldName
{
    fieldNameShort = @"Number";
    if ([fieldName isEqualToString:INVOICE_DATE_FIELD])       fieldNameShort = @"Date";
    if ([fieldName isEqualToString:INVOICE_CUSTOMER_FIELD])   fieldNameShort = @"Cust";
    if ([fieldName isEqualToString:INVOICE_SUPPLIER_FIELD])   fieldNameShort = @"Supp";
    if ([fieldName isEqualToString:INVOICE_HEADER_FIELD])     fieldNameShort = @"Header";
    if ([fieldName isEqualToString:INVOICE_COLUMN_FIELD])     fieldNameShort = @"Column";
    if ([fieldName isEqualToString:INVOICE_IGNORE_FIELD])     fieldNameShort = @"Ignore";
    if ([fieldName isEqualToString:INVOICE_TOTAL_FIELD])      fieldNameShort = @"Total";
}

//=============OCR VC=====================================================
-(void) resetSelectBox
{
    int xs = od.width/4;
    int ys = od.height/10;
    int xi = od.width/2  - xs/2;
    int yi = od.height/2 - ys/2;
    selectDocRect   = CGRectMake(xi, yi, xs, ys);
    selectBox.frame = [self documentToScreenRect:selectDocRect];
    selectBox.hidden = FALSE;
}



//=============OCR VC=====================================================
- (IBAction)clearSelect:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear All Fields: Are you sure?",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearFields];
                                                              [self stopMagView];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:firstAction];
    [alert addAction:secondAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}

//=============OCR VC=====================================================
// Handles add field OR cancel adding field
- (IBAction)addFieldSelect:(id)sender {
    
    if (editing || adjusting) //Cancel?
    {
        editing = adjusting = FALSE;
        [self clearScreenAfterEdit];
        [self stopMagView];
        
        return;
    }
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Add New Field"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add New Field",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Supplier",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_SUPPLIER_FIELD];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Number",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_NUMBER_FIELD];
                                                           }];
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Date",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_DATE_FIELD];
                                                          }];
    UIAlertAction *fourthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Customer",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_CUSTOMER_FIELD];
                                                           }];
    UIAlertAction *fifthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Column Header",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_HEADER_FIELD];
                                                          }];
    UIAlertAction *sixthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add a Column",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_COLUMN_FIELD];
                                                          }];
    UIAlertAction *seventhAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Total",nil)
                                                            style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                [self addNewField : INVOICE_TOTAL_FIELD];
                                                            }];
    UIAlertAction *eighthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore this Area",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_IGNORE_FIELD];
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
    [alert addAction:sixthAction];
    [alert addAction:seventhAction];
    [alert addAction:eighthAction];
    
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
} //end addFieldSelect

//=============OCR VC=====================================================
- (IBAction)promptForAdjust:(id)sender {
    
    NSString *fn    = [ot getBoxFieldName:adjustSelect];
    NSString *title = [NSString stringWithFormat:@"Selected %@\n[%@]",
                       fn,[ot getAllTags:adjustSelect]];
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:title];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Adjust Position and Size",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self adjustField];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete this box",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self->ot deleteBox:self->adjustSelect];
                                                               [self->ot saveTemplatesToDisk:self->supplierName];
                                                               self->spinner.hidden = FALSE;
                                                               [self->spinner startAnimating];
                                                               [self->act saveActivityToParse:@"...template:deleteBox" : fn];

                                                               [self->ot saveToParse:self->supplierName];
                                                               [self refreshOCRBoxes];
                                                           }];
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add Tag...",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self promptForNewTagToAdd:self];
                                                              
                                                          }];
    UIAlertAction *fourthAction;
    if ([ot getTagCount:adjustSelect] > 0)
        fourthAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Clear Tags",nil)
                                                style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                    [self->ot clearTags:self->adjustSelect];
                                                    [self->ot saveTemplatesToDisk:self->supplierName];
                                                    self->spinner.hidden = FALSE;
                                                    [self->spinner startAnimating];
                                                    [self->act saveActivityToParse:@"...template:clearTags" : fn];
                                                    [self->ot saveToParse:self->supplierName];
                                                }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    //DHS 3/13: Add owner's ability to delete puzzle
    [alert addAction:firstAction];
    [alert addAction:secondAction];
    [alert addAction:thirdAction];
    if ([ot getTagCount:adjustSelect] > 0) [alert addAction:fourthAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
} //end promptForAdjust

//=============OCR VC=====================================================
- (IBAction)promptForNewTagToAdd:(id)sender {
    NSArray*actions = [[NSArray alloc] initWithObjects:
                       TOP_TAG_TYPE,BOTTOM_TAG_TYPE,LEFT_TAG_TYPE,RIGHT_TAG_TYPE,
                       TOPMOST_TAG_TYPE,BOTTOMMOST_TAG_TYPE,LEFTMOST_TAG_TYPE,RIGHTMOST_TAG_TYPE,
                       ABOVE_TAG_TYPE,BELOW_TAG_TYPE,LEFTOF_TAG_TYPE,RIGHTOF_TAG_TYPE,
                       HCENTER_TAG_TYPE,HALIGN_TAG_TYPE,VCENTER_TAG_TYPE,VALIGN_TAG_TYPE , nil];
    NSArray *actionNames = [[NSArray alloc] initWithObjects:
                            @"Top",@"Bottom",@"Left",@"Right",
                            @"Topmost",@"Bottommost",@"Leftmost",@"Rightmost",
                            @"Above",@"Below",@"Leftof",@"Rightof",
                            @"HCenter",@"VCenter",@"HAlign",@"VAlign",nil];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select A Tag",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    int index=0;
    for (NSString *aname in actionNames)
    {
        UIAlertAction *nextAction = [UIAlertAction actionWithTitle:NSLocalizedString(aname,nil)
                                                             style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                 [self addTag:[actions objectAtIndex:index]];
                                                             }];
        [alert addAction:nextAction];
        index++;
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end promptForInvoiceNumberFormat

//=============OCR VC=====================================================
-(void) addTag : (NSString*)tag
{
    NSLog(@" addTag %@",tag);
    [ot addTag:adjustSelect:tag];
    [ot saveTemplatesToDisk:supplierName];
    spinner.hidden = FALSE;
    [spinner startAnimating];
    [act saveActivityToParse:@"...template:addTag" : tag];
    [ot saveToParse:supplierName];
} //end addTag



//=============OCR VC=====================================================
- (IBAction)doneSelect:(id)sender {
    if (editing || adjusting)
    {
        {
            fieldFormat = DEFAULT_FIELD_FORMAT;
            [self finishAndAddBox];
        }
    }
    else{
        [self dismiss];
        
    }
} //end doneSelect

//=============OCR VC=====================================================
-(void) finishAndAddBox
{
    //NOTE: this rect has to be scaled and offset for varying page sizes
    //  and text offsets!
    CGRect r = [self getDocumentFrameFromSelectBox];
    if (adjusting) [ot deleteBox:adjustSelect]; //Adjust? Replace box
    [ot addBox : r : fieldName : fieldFormat];
    editing = adjusting = FALSE;
    [ot dump];
    [ot saveTemplatesToDisk:supplierName];
    spinner.hidden = FALSE;
    [spinner startAnimating];
    [act saveActivityToParse:@"...template:addBox" : fieldName];
    [ot saveToParse:supplierName];
    [self clearScreenAfterEdit];
    [self stopMagView];
    
}

//=============OCR VC=====================================================
-(void) clearScreenAfterEdit
{
    _LHArrowView.hidden     = TRUE;
    _RHArrowView.hidden     = TRUE;
    selectBox.hidden        = TRUE;
    _instructionsLabel.text = @"...";
    [_wordsLabel setText:@""];
    
    [_addFieldButton setTitle:@"Add Field" forState:UIControlStateNormal];
    [self refreshOCRBoxes];
    
}

//=============OCR VC=====================================================
-(int) screenToDocumentX : (int) xin
{
    double dx = (double)xin * docXConv;
    //    double dx = ((double)xin - (double)_inputImage.frame.origin.x) * docXConv;
    return (int)floor(dx + 0.5);  //This is needed to get NEAREST INT!
}

//=============OCR VC=====================================================
-(int) screenToDocumentY : (int) yin
{
    double dy = (double)yin * docYConv;
    //    double dy = ((double)yin - (double)_inputImage.frame.origin.y) * docYConv;
    return (int)floor(dy + 0.5);  //This is needed to get NEAREST INT!
}

//=============OCR VC=====================================================
-(int) screenToDocumentW : (int) win
{
    return (int)floor((double)(win  * docXConv) + 0.5);
}

//=============OCR VC=====================================================
-(int) screenToDocumentH : (int) hin
{
    return (int)floor((double)(hin  * docYConv) + 0.5);
}


//=============OCR VC=====================================================
-(int) documentToScreenX : (int) xin
{
    double dx = ((double)xin / docXConv + (double)_inputImage.frame.origin.x);
    return (int)floor(dx + 0.5);  //This is needed to get NEAREST INT!
}

//=============OCR VC=====================================================
-(int) documentToScreenY : (int) yin
{
    double dy = ((double)yin / docYConv + (double)_inputImage.frame.origin.y);
    return (int)floor(dy + 0.5);  //This is needed to get NEAREST INT!
}

//=============OCR VC=====================================================
-(int) documentToScreenW : (int) win
{
    return (int)floor((double)(win  / docXConv) + 0.5);
}

//=============OCR VC=====================================================
-(int) documentToScreenH : (int) hin
{
    return (int)floor((double)(hin  / docYConv) + 0.5);
}


//=============OCR VC=====================================================
-(CGRect) documentToScreenRect : (CGRect) docRect
{
    int xi,yi,xs,ys;
    xi = [self documentToScreenX:docRect.origin.x];
    yi = [self documentToScreenY:docRect.origin.y];
    xs = [self documentToScreenW:docRect.size.width];
    ys = [self documentToScreenH:docRect.size.height];
    return CGRectMake(xi, yi, xs, ys);
} //documentToScreenRect



//=============OCR VC=====================================================
-(CGRect) getDocumentFrameFromSelectBox
{
    CGRect r = _inputImage.frame;
    int xi,yi,xs,ys;
    xi = r.origin.x;
    yi = r.origin.y;
    xs = r.size.width;
    ys = r.size.height;
    CGRect rs = selectBox.frame;
    //NSLog(@" sr1 %@",NSStringFromCGRect(rs));
    
    int docx = [self screenToDocumentX : rs.origin.x];
    int docy = [self screenToDocumentY : rs.origin.y];
    int docw = [self screenToDocumentW : rs.size.width];
    int doch = [self screenToDocumentH : rs.size.height];
    _instructionsLabel.text = [NSString stringWithFormat:
                               @"%@:XY(%d,%d)WH(%d,%d)",fieldNameShort,docx,docy,docw,doch];
    return CGRectMake(docx, docy, docw, doch);
} //end getDocumentFrameFromSelectBox


//=============OCR VC=====================================================
// Handles touch dragging
-(void) dragSelectBox : (int) xt : (int) yt
{
    CGRect rr = selectBox.frame;
    selectBox.frame = CGRectMake(xt, yt, rr.size.width, rr.size.height);
    [self setupMagView : xt : yt];
    [self getWordsInBox];
    [self getDocumentFrameFromSelectBox]; //Just updates screen/ toss return val

} //end dragSelectBox


//=============OCR VC=====================================================
// Handles arrow up/down/etc
-(void) moveOrResizeSelectBox : (int) xdel : (int) ydel : (int) xsdel : (int) ysdel
{
    CGRect r = selectBox.frame;
    NSLog(@" clugex %d clugey %d",clugex,clugey);
    int xi,yi,xs,ys;
    xi = r.origin.x;
    yi = r.origin.y;
    xs = r.size.width;
    ys = r.size.height;
    yi+=ydel;
    xi+=xdel;
    ys+=ysdel;
    xs+=xsdel;
    int dx = pageRect.origin.x;
    int dy = pageRect.origin.y;
    int dw = pageRect.size.width;
    int dh = pageRect.size.height;
    if (xs<arrowLHStepSize) xs = arrowLHStepSize;
    if (ys<arrowLHStepSize) ys = arrowLHStepSize;
    if (xs>dw) xs = dw;
    if (ys>dh) ys = dh;
    dy+=24; //NOTCH?
    if (xi < 0) xi = 0;
    if (yi < 0) yi = 0;
    //    if (xi < dx) xi = dx;
    //    if (yi < dy) yi = dy;
    if (xi+xs > dx+dw) xi = (dx+dw) - xs;
    if (yi+ys > dy+dh) yi = (dy+dh) - ys;
    selectBox.frame = CGRectMake(xi, yi, xs, ys);
    
    [self setupMagView : xi : yi];
    [self getWordsInBox];
    
    [self getDocumentFrameFromSelectBox]; //Just updates screen/ toss return val
}

//=============OCR VC=====================================================
-(void) getWordsInBox
{
    CGRect r = selectBox.frame;
    int xi,yi,xs,ys;
    xi = [self screenToDocumentX:r.origin.x];
    yi = [self screenToDocumentY:r.origin.y];
    xs = [self screenToDocumentW :r.size.width];
    ys = [self screenToDocumentH :r.size.height];
    NSLog(@" xywh %d %d : %d %d",xi,yi,xs,ys);
    CGRect r2 =CGRectMake(xi, yi, xs, ys);
    //NSLog(@" ...docrect %@",NSStringFromCGRect(r2));
    NSMutableArray *a = [od findAllWordStringsInRect:r2];
    NSString* wstr = @"";
    int count = 0;
    for (NSString *s in a)
    {
        wstr = [wstr stringByAppendingString:[NSString stringWithFormat:@"%@,",s]];
        count++;
    }
    if (count == 0) wstr = @"no text...";
    NSLog(@" wordsinbox %@",wstr);
    [_wordsLabel setText:wstr];
    //NSLog(@" annnd array %@",wstr);
}

//=============OCR VC=====================================================
- (IBAction)nextDocSelect:(id)sender
{
    docnum++;
    if (docnum > 4) docnum = 1;
    [self clearOverlay];
    if (OCR_mode == 1) //Get stubbed data...
    {
        NSLog(@" ocrmode 1:  nextdoc[%d] %@",docnum,supplierName);
        [self loadStubbedOCRData];
        spinner.hidden = FALSE;
        [spinner startAnimating];
        [ot readFromParse:supplierName]; //Unpacks template and loads it from DB
    }
    else{ //Do Full OCR
        NSLog(@" ocrmode 2: nextdoc[%d] %@",docnum,supplierName);

    }
}


//=============OCR VC=====================================================
- (IBAction)arrowDownSelect:(id)sender {
    UIButton *b = (UIButton *)sender;
    if (b.tag > 100) //LH arrows
        [self moveOrResizeSelectBox:0 :arrowLHStepSize:0:0];
    else{
        //FOR MAGVIEW CALIBRATION clugey++;
        [self moveOrResizeSelectBox:0:0:0 :arrowRHStepSize];
    }
}


//=============OCR VC=====================================================
- (IBAction)arrowUpSelect:(id)sender {
    UIButton *b = (UIButton *)sender;
    if (b.tag > 100) //LH arrows
        [self moveOrResizeSelectBox:0 :-arrowLHStepSize:0:0];
    else
    {
        //FOR MAGVIEW CALIBRATION clugey--;
        [self moveOrResizeSelectBox:0:0:0 :-arrowRHStepSize];
    }
}


//=============OCR VC=====================================================
- (IBAction)arrowLeftSelect:(id)sender {
    UIButton *b = (UIButton *)sender;
    if (b.tag > 100) //LH arrows
        [self moveOrResizeSelectBox:-arrowLHStepSize:0:0:0];
    else
    {
        //FOR MAGVIEW CALIBRATION clugex--;
        [self moveOrResizeSelectBox:0:0:-arrowRHStepSize:0 ];
    }
}

//=============OCR VC=====================================================
- (IBAction)arrowRightSelect:(id)sender {
    UIButton *b = (UIButton *)sender;
    if (b.tag > 100) //LH arrows
        [self moveOrResizeSelectBox:arrowLHStepSize:0:0:0];
    else
    {
        //FOR MAGVIEW CALIBRATION clugex++;
        [self moveOrResizeSelectBox:0:0:arrowRHStepSize:0 ];
    }
}


//======(PixUtils)==========================================
-(void) alertMessage : (NSString *) title : (NSString *) message
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:title
                                 message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"OK"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    //Handle your yes please button action here
                                }];
    [alert addAction:yesButton];
    [self presentViewController:alert animated:YES completion:nil];
} //end alertMessage

//=============OCR VC=====================================================
//Doesn't work in simulator??? huh??
-(void) mailit : (NSString *)s
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        [mail setSubject:@"Test CSV output"];
        [mail setMessageBody:s isHTML:NO];
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



//=============OCR VC=====================================================
//- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
//                 didFinishWithResult:(MessageComposeResult)result
//{
//    [self dismissViewControllerAnimated:YES completion:NULL];
//}



//=============OCR VC=====================================================
- (IBAction)arrowCenterSelect:(id)sender
{
    UIButton *b = (UIButton *)sender;
    BOOL newstate = FALSE;
    if (b.tag > 100) //LH arrows
    {
        newstate = lhArrowsFast = !lhArrowsFast;
        arrowLHStepSize = 1;
        if (newstate) arrowLHStepSize = 10;
    }
    else
    {
        newstate = rhArrowsFast = !rhArrowsFast;
        arrowRHStepSize = 1;
        if (newstate) arrowRHStepSize = 10;
    }
    [self updateCenterArrowButtons];
} //end arrowCenterSelect

//=============OCR VC=====================================================
-(void) updateCenterArrowButtons
{
    if (lhArrowsFast)
        [_lhCenterButton setBackgroundImage : fastIcon forState:UIControlStateNormal];
    else
        [_lhCenterButton setBackgroundImage : slowIcon forState:UIControlStateNormal];
    
    if (rhArrowsFast)
        [_rhCenterButton setBackgroundImage : fastIcon forState:UIControlStateNormal];
    else
        [_rhCenterButton setBackgroundImage : slowIcon forState:UIControlStateNormal];
    
}

#pragma mark - OCRTemplateDelegate

//=============OCR VC=====================================================
- (void)didReadTemplate
{
    NSLog(@" didReadTemplate...");
    [self refreshOCRBoxes];
    
    //look at our image, is it portrait or landscape?
    [ot setTemplateOrientation:(int)_inputImage.image.size.width :(int)_inputImage.image.size.height ];
    CGRect tlDocumentRect = [od getTLRect];
    CGRect trDocumentRect = [od getTRRect];
    //Force scaling to 1:1, since the template document IS the same as the scanned document
    [od computeScaling : tlDocumentRect : trDocumentRect];

    spinner.hidden = TRUE;
    [spinner stopAnimating];
}


//=============OCR VC=====================================================
- (void)didSaveTemplate
{
    NSLog(@" didSaveTemplate...");
    spinner.hidden = TRUE;
    [spinner stopAnimating];
}


#pragma mark - invoiceTableDelegate
//=============OCR VC=====================================================
- (void)didSaveInvoiceTable:(NSString *) s
{
    NSLog(@" Invoice TABLE SAVED (OCR VC)");

}


#pragma mark - EXPTableDelegate

//=============OCR VC=====================================================
- (void)didSaveEXPTable  : (NSArray *)a
{
    NSLog(@" EXP TABLE SAVED (OCR VC)");
    //Time to setup invoice object too!
    [it clearObjectIds];
    [it setupVendorTableName : supplierName];
    NSString *its = [NSString stringWithFormat:@"%4.2f",invoiceTotal];
    its = [od cleanupPrice:its]; //Make sure total is formatted!
    [it setBasicFields:invoiceDate :invoiceNumberString : its : supplierName : invoiceCustomer : @"EmptyPDF" : @"1"];
    for (NSString *objID in a) [it addInvoiceItemByObjectID : objID];
    [it saveToParse];
} //end didSaveEXPTable


//=============OCR VC=====================================================
- (void)didReadEXPTableAsStrings : (NSString *)s
{
    spinner.hidden = TRUE;
    [spinner stopAnimating];

    [self mailit: s];
}

#pragma mark - OCRTopObjectDelegate

//=============<OCRTopObjectDelegate>=====================================================
- (void)didSaveOCRDataToParse : (NSString *) s
{
    NSLog(@" OK: full OCR -> DB done, invoice %@",s);
}


//=============<OCRTopObjectDelegate>=====================================================
- (void)errorPerformingOCR : (NSString *) errMsg
{
     NSLog(@" errorPerformingOCR %@",errMsg);
}

//=============<OCRTopObjectDelegate>=====================================================
- (void)fatalErrorPerformingOCR : (NSString *) errMsg
{
    NSLog(@" fatalErrorPerformingOCR %@",errMsg);
}

//=============<OCRTopObjectDelegate>=====================================================
- (void)errorSavingEXP : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName
{
    NSLog(@" errorSavingEXP %@:%@:%@",errMsg,objectID,productName);
}


@end
