//
//   _____    _ _ _  _____                    _       _     __     ______
//  | ____|__| (_) ||_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//  |  _| / _` | | __|| |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//  | |__| (_| | | |_ | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//  |_____\__,_|_|\__||_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                     |_|
//
//  EditTemplateVC.m
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
//  3/17 Added hookups for checkVC passed image/OCRtext
//  4/1  Looks good for template create / edit
//  4/5  remove ocr_mode, nextDoc, email, all stubbed stuff
#import "EditTemplateVC.h"

 

@implementation EditTemplateVC

//=============EditTemplateVC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;

    od = [[OCRDocument alloc] init];
    ot = [[OCRTemplate alloc] init];
    ot.delegate = self;  //1/16 WHY WASN'T THIS HERE!?
    
    oto = [OCRTopObject sharedInstance];
    oto.delegate = self;

    act = [[ActivityTable alloc] init];
    act.delegate = self;
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    [dbt setParent:self];

    pc = [PDFCache sharedInstance];

    arrowLHStepSize = 10;
    arrowRHStepSize = 10;
    editing = adjusting = FALSE;
    
    docnum = 4;

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
    _incomingVendor  = @"";

    smartCount = 0;
    
    _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];

    return self;
}



//=============EditTemplateVC=====================================================
-(void) loadView
{
    [super loadView];
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    viewWid = (int)csz.width;
    viewHit = (int)csz.height;
    viewW2  = viewWid/2;
    viewH2  = viewHit/2;
}

//=============AddTemplate VC=====================================================
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}


//=============EditTemplateVC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 4/1 Add spinner busy indicator...
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, viewWid, viewHit)];
    [self.view addSubview:spv];
    if (_incomingOCRText.length < 1) //Not being invoked by AddTemplateVC->CheckTemplateVC?
    {
        //Normal mode ( GET RID OF MODE 1)
        [spv start : @"find templates..."];
        [ot readFromParse:@"*"]; //read all templates
    }
    else // 3/17 coming in from checkTemplateVC...load up our incoming image...
    {
        vendor            = _incomingVendor;
        _inputImage.image = _incomingImage;
        NSData *jsonData  = [_incomingOCRText dataUsingEncoding:NSUTF8StringEncoding];
        NSError *e;
        NSDictionary *jdict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                              options:NSJSONReadingMutableContainers error:&e];
        docFlipped90 = ([_incomingVendor isEqualToString:@"HFM"]);
        selectFnameForTemplate = @"dog.png"; //DO I need this?
        
        [od setupDocumentAndParseJDON : selectFnameForTemplate : jdict : docFlipped90]; //Last arg is flip: true for HFM
        tlRect = [od getTLRect];
        trRect = [od getTRRect];
        docRect = [od getDocRect]; //Get min/max limits of printed text
        [ot setOriginalRects : tlRect : trRect];
        ot.supplierName = vendor; //Pass along supplier name to template
        ot.pdfFile      = _incomingImageFilename;
        //Set unit scaling
        [od setUnitScaling];
        [self clearFields]; //This clears vendor Parse entry too!
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
    
    [self scaleImageViewToFitDocument];
    
    //4/1 notifications from OCRTopObject singleton...
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didPerformOCR:)
                                                 name:@"didPerformOCR" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(errorPerformingOCR:)
                                                 name:@"errorPerformingOCR" object:nil];

    
} //end viewDidLoad

//=============EditTemplateVC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    it.parentUp = FALSE; // 2/9 Tell invoiceTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
    
}


//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
-(void) computeDocumentConversion
{
    //4/30 scale document vs viewport...
    int iwid = _incomingImage.size.width;
    int ihit = _incomingImage.size.height;
    NSLog(@" iwid/hit %d %d",iwid,ihit);
    CGRect screenRect = _inputImage.frame;
    NSLog(@" swid/hit %f %f",screenRect.size.width,screenRect.size.height);
    docXConv = (double)iwid / (double)screenRect.size.width ;
    docYConv = (double)ihit / (double)screenRect.size.height ;

}

//=============EditTemplateVC=====================================================
// NOTE this gets called WHENEVER select box moves!!!
- (void)viewWillLayoutSubviews {
    //Make sure screen has settled before adding overlays!
    [self refreshOCRBoxes];
    [self computeDocumentConversion];
    

    if (selectBox == nil) //Add selection box...
    {
        selectDocRect = CGRectMake(0, 0, 100, 100); //
        selectBox = [[UIView alloc] initWithFrame:[self documentToScreenRect:selectDocRect]];
        selectBox.backgroundColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.0 alpha:0.5];
        [_selectOverlayView addSubview:selectBox];
        selectBox.hidden = TRUE;
        
    }
    
    
}

//=============EditTemplateVC=====================================================
-(void) stopMagView
{
    magView.hidden = TRUE;
}

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
// 4/1 passed in list of template objects, choose one by vendor
-(void) templateVendorMenu : (NSArray *)a
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:
                                            @"Select Template by Vendor"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Template by Vendor"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (int i=0;i<a.count;i++)
    {
        PFObject *pfo = a[i];
        NSString *v = pfo[@"vendor"];
        [alert addAction : [UIAlertAction actionWithTitle:v
                                                    style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                        [self setupImageForVendor : a : v : i];
                                                    }]] ;
    }
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   [self dismiss];
                                               }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end templateVendorMenu


//=============EditTemplateVC=====================================================
-(void) setupImageForVendor : (NSArray *)a : (NSString *) v : (int) i
{
    [ot loadTemplateFromPFObject:a :i]; //Loadit!
    vendor = v;
    _incomingImageFilename = self->ot.pdfFile;

    //Cache hit?
    UIImage *ii = [pc getImageByID:_incomingImageFilename : 1];
    if (ii == nil)
    {
        [spv start : @"Download image..."];
        [dbt downloadImages:self->_incomingImageFilename];
    }
    else
    {
        NSLog(@" PDF Cache hit..."); //asdf
        _incomingImage = ii;
        [self finishWithDownloadedImage];
    }
} //end setupImageForVendor


//=============EditTemplateVC=====================================================
//  Called after PDF cache hit, or on return from dbt download...
-(void) finishWithDownloadedImage
{
    _inputImage.image = _incomingImage;
    [self scaleImageViewToFitDocument];
    [self computeDocumentConversion]; //Just got image, need to do conversion!
    [self refreshOCRBoxes];
    //OK now its OCR time...
    oto.imageFileName = _incomingImageFilename;
    oto.ot = nil; //Hand template down to oto
    [spv start:@"Perform OCR..."];
    [oto performOCROnImage : _incomingImageFilename : _incomingImage ];

}


//=============EditTemplateVC=====================================================
-(void) clearOverlay
{
    NSArray *viewsToRemove = [_overlayView subviews];
    for (UIView*v in viewsToRemove) [v removeFromSuperview];
    
}

//=============EditTemplateVC=====================================================
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


//=============EditTemplateVC=====================================================
// Apply template to document, output basic fields
- (IBAction)testSelect:(id)sender {
    //4/30 use incoming image...
    NSArray *farray = [_incomingImageFilename componentsSeparatedByString:@"/"];
    if (farray.count > 0) oto.imageFileName = farray[farray.count-1]; //Just get last component...
    else oto.imageFileName = _incomingImageFilename;
    oto.ot = ot; //Hand template down to oto
    [oto applyTemplate : ot : 0]; //4/30 MUST use page 0!
    [oto writeEXPToParse : 0]; //Note 2nd arg is page!
    NSString *OCR_Results_Dump = [oto dumpResults];
    [self alertMessage:@"Invoice Dump" :OCR_Results_Dump];
} //end testSelect



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

//=============EditTemplateVC=====================================================
-(NSDictionary*) getJSON : (NSString *)s
{
    NSData *jsonData = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&e];
    return dict;
}

//=============EditTemplateVC=====================================================
-(void) clearFields
{
    [ot clearFields];
    // ...save to PInv_ActivityType_key and PInv_ActivityData keys...
    [act saveActivityToParse:@"Clear Template" : vendor];
    [ot saveToParse:self->vendor];
    // Set limits where text was found at top / left / right,
    //  used for re-scaling if invoice was shrunk or whatever
    [ot setOriginalRects:tlRect :trRect];
    [self refreshOCRBoxes];
}



//=============EditTemplateVC=====================================================
// setups field for moving around and positioning:
//   finishAndAddBox does actual creation of new template box
-(void) addNewField : (NSString*) ftype
{
    //Multiple columns are desired, other types of fields are one-only!
    // 2/15 make a special array for here...
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

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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



//=============EditTemplateVC=====================================================
- (IBAction)clearSelect:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Clear All Fields: Are you sure?",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self clearFields];
                                                              [self stopMagView];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];
} //end clearSelect

//=============EditTemplateVC=====================================================
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
    // 2/15 cleanup...
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Supplier",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_SUPPLIER_FIELD];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Number",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_NUMBER_FIELD];
                                                           }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Date",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_DATE_FIELD];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Customer",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_CUSTOMER_FIELD];
                                                           }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Header across columns   ",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_HEADER_FIELD];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Item# Column",nil)
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self addNewField : INVOICE_COLUMN_ITEM_FIELD];
                                                          }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Description Column",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self addNewField : INVOICE_COLUMN_DESCRIPTION_FIELD];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Quantity Column",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self addNewField : INVOICE_COLUMN_QUANTITY_FIELD];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Price/Item Column",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self addNewField : INVOICE_COLUMN_PRICE_FIELD];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Total Amount Column",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                  [self addNewField : INVOICE_COLUMN_AMOUNT_FIELD];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add Invoice Total",nil)
                                                            style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                [self addNewField : INVOICE_TOTAL_FIELD];
                                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore this Area",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self addNewField : INVOICE_IGNORE_FIELD];
                                                           }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];
} //end addFieldSelect

//=============EditTemplateVC=====================================================
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
                                                               [self->ot saveTemplatesToDisk:self->vendor];
                                                               [self->spv start : @"delete Box..."];
                                                               [self->act saveActivityToParse:@"...template:deleteBox" : fn];
                                                               [self->ot saveToParse:self->vendor];
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
                                                    [self->ot saveTemplatesToDisk:self->vendor];
                                                    [self->spv start : @"clear Tags..."];
                                                    [self->act saveActivityToParse:@"...template:clearTags" : fn];
                                                    [self->ot saveToParse:self->vendor];
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

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
-(void) addTag : (NSString*)tag
{
    NSLog(@" addTag %@",tag);
    [ot addTag:adjustSelect:tag];  //passed down to OCRBox:addTag
    [ot saveTemplatesToDisk:vendor];
    [spv start : @"add Tag..."];
    [act saveActivityToParse:@"...template:addTag" : tag];
    [ot saveToParse:vendor];
} //end addTag



//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
-(void) finishAndAddBox
{
    //NOTE: this rect has to be scaled and offset for varying page sizes
    //  and text offsets!
    CGRect r = [self getDocumentFrameFromSelectBox];
    if (adjusting) [ot deleteBox:adjustSelect]; //Adjust? Replace box
    // 2/15 NOTE for column boxes, the top/bottoms get auto-aligned
    [ot addBox : r : fieldName : fieldFormat];
    editing = adjusting = FALSE;
    [ot dump];
    [ot saveTemplatesToDisk:vendor];
    [spv start : @"add Box..."];
    [act saveActivityToParse:@"...template:addBox" : fieldName];
    [ot saveToParse:vendor];
    [self clearScreenAfterEdit];
    [self stopMagView];
} //end finishAndAddBox

//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
-(int) screenToDocumentX : (int) xin
{
    double dx = (double)xin * docXConv;
    //    double dx = ((double)xin - (double)_inputImage.frame.origin.x) * docXConv;
    return (int)floor(dx + 0.5);  //This is needed to get NEAREST INT!
}

//=============EditTemplateVC=====================================================
-(int) screenToDocumentY : (int) yin
{
    double dy = (double)yin * docYConv;
    //    double dy = ((double)yin - (double)_inputImage.frame.origin.y) * docYConv;
    return (int)floor(dy + 0.5);  //This is needed to get NEAREST INT!
}

//=============EditTemplateVC=====================================================
-(int) screenToDocumentW : (int) win
{
    return (int)floor((double)(win  * docXConv) + 0.5);
}

//=============EditTemplateVC=====================================================
-(int) screenToDocumentH : (int) hin
{
    return (int)floor((double)(hin  * docYConv) + 0.5);
}


//=============EditTemplateVC=====================================================
-(int) documentToScreenX : (int) xin
{
    double dx = ((double)xin / docXConv + (double)_inputImage.frame.origin.x);
    return (int)floor(dx + 0.5);  //This is needed to get NEAREST INT!
}

//=============EditTemplateVC=====================================================
-(int) documentToScreenY : (int) yin
{
    double dy = ((double)yin / docYConv + (double)_inputImage.frame.origin.y);
    return (int)floor(dy + 0.5);  //This is needed to get NEAREST INT!
}

//=============EditTemplateVC=====================================================
-(int) documentToScreenW : (int) win
{
    return (int)floor((double)(win  / docXConv) + 0.5);
}

//=============EditTemplateVC=====================================================
-(int) documentToScreenH : (int) hin
{
    return (int)floor((double)(hin  / docYConv) + 0.5);
}


//=============EditTemplateVC=====================================================
-(CGRect) documentToScreenRect : (CGRect) docRect
{
    int xi,yi,xs,ys;
    xi = [self documentToScreenX:docRect.origin.x];
    yi = [self documentToScreenY:docRect.origin.y];
    xs = [self documentToScreenW:docRect.size.width];
    ys = [self documentToScreenH:docRect.size.height];
    return CGRectMake(xi, yi, xs, ys);
} //documentToScreenRect



//=============EditTemplateVC=====================================================
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


//=============EditTemplateVC=====================================================
// Handles touch dragging
-(void) dragSelectBox : (int) xt : (int) yt
{
    CGRect rr = selectBox.frame;
    selectBox.frame = CGRectMake(xt, yt, rr.size.width, rr.size.height);
    [self setupMagView : xt : yt];
    [self getWordsInBox];
    [self getDocumentFrameFromSelectBox]; //Just updates screen/ toss return val

} //end dragSelectBox


//=============EditTemplateVC=====================================================
// Handles arrow up/down/etc
-(void) moveOrResizeSelectBox : (int) xdel : (int) ydel : (int) xsdel : (int) ysdel
{
    CGRect r = selectBox.frame;
    //NSLog(@" clugex %d clugey %d",clugex,clugey);
    int xi,yi,xs,ys;
    xi = r.origin.x;
    yi = r.origin.y;
    xs = r.size.width;
    ys = r.size.height;
    yi+=ydel;
    xi+=xdel;
    ys+=ysdel;
    xs+=xsdel;
    //int dx = pageRect.origin.x;
    int dy = pageRect.origin.y;
    //int dw = pageRect.size.width;
    //int dh = pageRect.size.height;
    if (xs<arrowLHStepSize) xs = arrowLHStepSize;
    if (ys<arrowLHStepSize) ys = arrowLHStepSize;
   //4/30 no upper limits... if (xs>dw) xs = dw;
   //4/30 no upper limits... if (ys>dh) ys = dh;
    dy+=24; //NOTCH?
    if (xi < 0) xi = 0;
    if (yi < 0) yi = 0;
    //    if (xi < dx) xi = dx;
    //    if (yi < dy) yi = dy;
   //4/30 no upper limits... if (xi+xs > dx+dw) xi = (dx+dw) - xs;
   //4/30 no upper limits... if (yi+ys > dy+dh) yi = (dy+dh) - ys;
    selectBox.frame = CGRectMake(xi, yi, xs, ys);
    
    [self setupMagView : xi : yi];
    [self getWordsInBox];
    
    [self getDocumentFrameFromSelectBox]; //Just updates screen/ toss return val
}

//=============EditTemplateVC=====================================================
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
    NSMutableArray *a = [od findAllWordStringsInDocumentRect:r2];
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



//=============EditTemplateVC=====================================================
- (IBAction)arrowDownSelect:(id)sender {
    UIButton *b = (UIButton *)sender;
    if (b.tag > 100) //LH arrows
        [self moveOrResizeSelectBox:0 :arrowLHStepSize:0:0];
    else{
        //FOR MAGVIEW CALIBRATION clugey++;
        [self moveOrResizeSelectBox:0:0:0 :arrowRHStepSize];
    }
}


//=============EditTemplateVC=====================================================
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


//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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



//=============EditTemplateVC=====================================================
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

//=============EditTemplateVC=====================================================
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



//=============<OCRTopObject notification>=====================================================
- (void)errorPerformingOCR:(NSNotification *)notification
{
    NSString *errmsg = (NSString*)notification.object;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@" error on OCR... %@",errmsg);
        [self->spv stop];
    });
}

//=============<OCRTopObject notification>=====================================================
// Called by OCR notification...
-(void) finishWithOCR
{
    _incomingOCRText = [oto getRawResult];
    NSData *jsonData  = [_incomingOCRText dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *jdict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                          options:NSJSONReadingMutableContainers error:&e];
    docFlipped90 = ([vendor isEqualToString:@"HFM"]);
    selectFnameForTemplate = @"dog.png"; //DO I need this?
    [od setupDocumentAndParseJDON : selectFnameForTemplate : jdict : docFlipped90]; //Last arg is flip: true for HFM
    tlRect = [od getTLRect];
    trRect = [od getTRRect];
    docRect = [od getDocRect]; //Get min/max limits of printed text
    [ot setOriginalRects : tlRect : trRect];
    ot.supplierName = vendor; //Pass along supplier name to template
    ot.pdfFile      = _incomingImageFilename;
    //Is this OK?
    od.width        = _incomingImage.size.width;
    od.height       = _incomingImage.size.height;
    //Set unit scaling
    [od setUnitScaling];
    
} //end finishWithOCR

//=============<OCRTopObject notification>=====================================================
// 3/17
- (void)didPerformOCR:(NSNotification *)notification
{
    NSLog(@" didPerformOCR...");
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self finishWithOCR];
    });
} //end didPerformOCR





#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
- (void)didDownloadImages
{
    [spv stop];
    NSLog(@" dloaded dbox image... %@",_incomingImageFilename);
    _incomingImage = dbt.batchImages[0];
    [self finishWithDownloadedImage];
}

#pragma mark - OCRTemplateDelegate

//===========<OCRTemplateDelegate>===============================================
// Returns with the array of PFObjects read from template table
- (void)didReadTemplate  : (NSArray*) a
{
    NSLog(@" didReadTemplate...");
    if (a.count > 1) //Read a list of templates? Means go to menu next
    {
        [self templateVendorMenu : a];
    }
    else{ //Single template read? Load up fields, etc
        [self refreshOCRBoxes];
        //look at our image, is it portrait or landscape?
        [ot setTemplateOrientation:(int)_inputImage.image.size.width :(int)_inputImage.image.size.height ];
        CGRect tlDocumentRect = [od getTLRect];
        CGRect trDocumentRect = [od getTRRect];
        //Force scaling to 1:1, since the template document IS the same as the scanned document
        [od computeScaling : tlDocumentRect : trDocumentRect];
    }
    [spv stop];
}


//===========<OCRTemplateDelegate>===============================================
- (void)didSaveTemplate
{
    NSLog(@" didSaveTemplate...");
    [spv stop];
}


#pragma mark - invoiceTableDelegate
//===========<invoiceTableDelegate>===============================================
- (void)didSaveInvoiceTable:(NSString *) s
{
    NSLog(@" Invoice TABLE SAVED (OCR VC)");

}


//===========<invoiceTableDelegate>===============================================
#pragma mark - activityTableDelegate
- (void)didSaveActivity
{
    
}


#pragma mark - EXPTableDelegate

//===========<EXPTableDelegate>===============================================
- (void)didSaveEXPTable  : (NSArray *)a
{
    NSLog(@" EXP TABLE SAVED (OCR VC)");
    //Time to setup invoice object too!
    [it clearObjectIds];
    [it setupVendorTableName : vendor];
    NSString *its = [NSString stringWithFormat:@"%4.2f",invoiceTotal];
    its = [od cleanupPrice:its]; //Make sure total is formatted!
    [it setBasicFields:invoiceDate :invoiceNumberString : its : vendor : invoiceCustomer : @"EmptyPDF" : @"0" : @"1"];  //DGS 3/12
    for (NSString *objID in a) [it addInvoiceItemByObjectID : objID];
    [it saveToParse:FALSE]; //BOOL is lastPage arg...T/F???
} //end didSaveEXPTable



//===========<EXPTableDelegate>===============================================
// Called w/ bad product ID, or from errorInEXPRecord in EXP write
- (void)errorInEXPRecord  : (NSString *) errMsg : (NSString*) objectID : (NSString*) productName
{
    NSLog(@" errorInEXPRecord %@ : %@: %@",errMsg,objectID,productName);
} //end errorInEXPRecord

#pragma mark - OCRTopObjectDelegate

//===========<OCRTopObjectDelegate>===============================================
- (void)didSaveOCRDataToParse : (NSString *) s
{
    NSLog(@" OK: full OCR -> DB done, invoice %@",s);
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

//=============<OCRTopObjectDelegate>=====================================================
- (void)batchUpdate : (NSString *) s
{
    NSLog(@" ...stubbed batchUpdate %@",s);
}


@end
