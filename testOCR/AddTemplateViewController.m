//
//      _       _     _ _____                    _       _     __     ______
//     / \   __| | __| |_   _|__ _ __ ___  _ __ | | __ _| |_ __\ \   / / ___|
//    / _ \ / _` |/ _` | | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \ \ / / |
//   / ___ \ (_| | (_| | | |  __/ | | | | | |_) | | (_| | ||  __/\ V /| |___
//  /_/   \_\__,_|\__,_| |_|\___|_| |_| |_| .__/|_|\__,_|\__\___| \_/  \____|
//                                        |_|
//
//  AddTemplateViewController.m
//  testOCR
//
//  Created by Dave Scruton on 12/20/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "AddTemplateViewController.h"

@interface AddTemplateViewController ()

@end

@implementation AddTemplateViewController


NSString * steps[] = {
    @"Step 1: Choose a template image...",
    @"Step 2: Rotate / Deskew...",
    @"Step 3: Enhance..."

};


//=============OCR VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
 //   _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    it  = [[imageTools alloc] init];
    dbt = [[DropboxTools alloc] init];
    dbt.delegate = self;
    ot = [[OCRTemplate alloc] init];
    ot.delegate = self;  //1/16 WHY WASN'T THIS HERE!?

    
    pc  = [PDFCache sharedInstance];
    
    brightness  =  0.0;
    contrast    = saturation = 1.0;
    removeColor = FALSE;
    enhancing   = FALSE;
    coreImage   = [[CIImage alloc] init];
    vv          = [Vendors sharedInstance];
    vendorMode  = @"templates";
    return self;
}



//=============AddTemplate VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    gotPhoto = FALSE;
    //Hide some stuff at the beginning
    _rotateView.hidden        = TRUE;
    _gridOverlay.hidden       = TRUE;
    _loadButton.hidden        = TRUE;
    _nextButton.hidden        = TRUE;
    _enhanceView.hidden       = TRUE;
    [_removeColorButton setTitle:@"Remove Color" forState:UIControlStateNormal];
    // 1/19 Add spinner busy indicator...
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, viewWid, viewHit)];
    [self.view addSubview:spv];

}

//=============AddTemplate VC=====================================================
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //Get template folder contents...
    AppDelegate *tappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    templateFolder = tappDelegate.settings.templateFolder;
    //We will choose from the templates folder...
    [self vendorMenu];

    //First, are we coming back from something??
    if (_step != 0)
    {
        _step = 1; //Set back to deskew...
    }
//    else if (_step == 0 && _needPicker)
//    {
//        [self displayPhotoPicker];
//        _needPicker = FALSE;
//    }

    [self updateUI];
} //end viewDidAppear

//=============AddTemplate VC=====================================================
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
-(void) vendorMenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Vendor"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Vendor",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (int i=0;i<vv.vcount;i++)  //DHS 3/6
    {
        NSString *s = [vv getNameByIndex:i]; //DHS 3/6
        [alert addAction : [UIAlertAction actionWithTitle:s
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                          self->_vendor = s;
                                                          [self->spv start : @"Check Template Exists..."];
                                                          [self->ot checkVendorTemplate:s];
                                                        }]] ;
    }
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self dismiss];
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];

} //end vendorMenu

//=============AddTemplate VC=====================================================
-(void) choiceMenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Template Image"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Select Template Image",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    
    for (DBFILESMetadata *entry in fileEntries)
    {
        NSString *fname = entry.name;
        [alert addAction : [UIAlertAction actionWithTitle:fname
                                                    style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                        NSLog(@" chose %@",fname);
                                                        self->imagePath = [NSString stringWithFormat:
                                                                           @"/%@/%@",self->templateFolder,fname];
                                                        if ([self->pc imageExistsByID : self->imagePath : 1])
                                                        {
                                                            NSLog(@" ...cache HIT %@",self->imagePath);
                                                            self->_photo = [self->pc getImageByID : self->imagePath : 1];
                                                            self->gotPhoto = TRUE;
                                                            self->_step    = 1; //Set UI state...
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                                [self resetRotation];
                                                                [self updateUI];
                                                            });
                                                        } //end imageExists...
                                                        else{
                                                            [self->spv start : @"Load Template Image"];
                                                            //3/17 choose PDF from a staged file area...
                                                            if ([self->vendorMode isEqualToString:@"load"])
                                                            {
                                                                NSString *folderPath = [NSString stringWithFormat : @"%@/latestBatch/%@/%@",self->customerSelect,self->_vendor,fname];
                                                                [self->dbt downloadImages : folderPath];
                                                            }
                                                            else // 3/17  Is this still used?
                                                                [self->dbt downloadImages : self->imagePath];
                                                        }
                                                        
                                                    }]];
    }
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                               }]];
    [self presentViewController:alert animated:YES completion:nil];
    
} //end choiceMenu

//=============AddTemplate VC=====================================================
// We have customer / vendor, time to see whats there...
-(void) getVendorPDFFiles
{
    //AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [self->spv start : @"Get PDF List..."];
    NSString *folderPath = [NSString stringWithFormat : @"%@/latestBatch/%@",customerSelect,_vendor];
    [dbt getFolderList:folderPath];  //Rest handled in delegate callback...
} //end getVendorPDFFiles

//=============AddTemplate VC=====================================================
// We have customer / vendor, time to see whats there...
-(void) getTemplatePDFFiles
{
    //AppDelegate *bappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [self->spv start : @"Get PDF List..."];
    NSString *folderPath = [NSString stringWithFormat : @"/%@",templateFolder];
    [dbt getFolderList:folderPath];  //Rest handled in delegate callback...
} //end getTemplatePDFFiles


//=============AddTemplate VC=====================================================
-(void) scaleImageViewToFitDocument
{
    int iwid = _templateImage.image.size.width;
    int ihit = _templateImage.image.size.height;
    int xi,yi,xs,ys;
    double xscale = (double)viewWid / (double)iwid;
    yi = 90;
    xs = xscale * iwid;
    ys = xscale * ihit;
    xi = viewW2 - xs/2;
    CGRect rr = CGRectMake(xi, yi, xs, ys);
    NSLog(@" r %@",NSStringFromCGRect(rr));
    _templateImage.frame = rr;
} //end scaleImageViewToFitDocument


//=============AddTemplate VC=====================================================
- (IBAction)resetSelect:(id)sender
{
    [self resetRotation];
    _step = 1;
    rotAngle = rotAngleRadians = 0.0;
    showRotatedImage = FALSE;
    [self updateUI];
}



//=============AddTemplate VC=====================================================
- (IBAction)resetEnhanceSelect:(id)sender
{
    contrast    = 1.0;
    brightness  = 0.0;
    saturation  = 1.0;
    removeColor = FALSE;
    [self updateUI];
}

//=============AddTemplate VC=====================================================
- (IBAction)cancelSelect:(id)sender
{
    [self dismiss];

}

//=============AddTemplate VC=====================================================
- (IBAction)loadSelect:(id)sender
{
    // [self displayPhotoPicker];
}

//=============AddTemplate VC=====================================================
- (IBAction)deskewSelect:(id)sender
{
    UIImage *inputImage = _photo;
    if (showRotatedImage) inputImage = _rphoto;
    
    [it deskew:inputImage]; //This returns an image, but gets an error if i try getting it!
    double dskew = it.skewAngleFound;
    rotAngleRadians = dskew;
    rotAngle = 180.0 * (dskew / 3.141592627);
    showRotatedImage = TRUE;
    // Note: this may be using a pre-rotated image!
    //  for instance, if input was obviously 90 degrees off, then there will be a 90 deg
    //  starting rotation... it still may be skewed tho...
    _rphoto =  [it imageRotatedByRadians:rotAngleRadians img:inputImage];
    [self updateUI];

    NSLog(@" found skew angle %f (%fdeg)",rotAngleRadians,rotAngle);
//    UIImage *iskew = [it deskew:inputImage];
    //_skewAngleFound
}


//=============AddTemplate VC=====================================================
- (IBAction)p90Select:(id)sender
{
    [self rotateTemplatePhoto : 90.0];
}

//=============AddTemplate VC=====================================================
- (IBAction)p10Select:(id)sender {
    [self rotateTemplatePhoto : 10.0];
}

//=============AddTemplate VC=====================================================
- (IBAction)p1Select:(id)sender {
    [self rotateTemplatePhoto : 0.1];
}

//=============AddTemplate VC=====================================================
- (IBAction)m1Select:(id)sender {
    [self rotateTemplatePhoto : -0.1];
}

//=============AddTemplate VC=====================================================
- (IBAction)m10Select:(id)sender {
    [self rotateTemplatePhoto : -10.0];
}

//=============AddTemplate VC=====================================================
- (IBAction)m90Select:(id)sender {
    [self rotateTemplatePhoto : -90.0];
}

//=============AddTemplate VC=====================================================
- (IBAction)nextSelect:(id)sender
{
    if (_step == 1)
    {
        _step = 2;
    }
    else if (_step == 2)
    {
        //_step = 3;
        [self performSegueWithIdentifier:@"checkTemplateSegue" sender:@"addTemplateVC"];
    }
    [self updateUI];
}

//=============AddTemplate VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}

//=============AddTemplate VC=====================================================
-(void) customerMenu
{
    AppDelegate *tappDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    templateFolder = tappDelegate.settings.templateFolder;
    
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Select Customer:"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:30] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Select Customer:",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    for (NSString *cust in tappDelegate.cust.customerNames)
    {
        [alert addAction: [UIAlertAction actionWithTitle:cust
                                                   style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                       self->customerSelect = cust;
                                                       [self vendorMenu];
                                                   }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                              }]];
    [self presentViewController:alert animated:YES completion:nil];
} //end customerMenu


//=============AddTemplate VC=====================================================
// Handles last minute VC property setups prior to segues
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //NSLog(@" prepareForSegue: %@ sender %@",[segue identifier], sender);
    if([[segue identifier] isEqualToString:@"checkTemplateSegue"])
    {
        CheckTemplateVC *vc = (CheckTemplateVC*)[segue destinationViewController];
        vc.photo    = _templateImage.image;
        vc.fileName = imagePath;
        vc.vendor   = _vendor;
    }
}


//=============AddTemplate VC=====================================================
-(void) updateUI
{
    NSLog(@" updateui step %d showr %d",_step,showRotatedImage);
    if (_step == 1)  //Rotate: two possible states here...
    {
        if (showRotatedImage)
            _titeLabel.text = [NSString stringWithFormat:@"Rotated by %f degrees",rotAngle];
        else
            _titeLabel.text = steps[_step];
    }
    else //other steps...
    {
        _titeLabel.text = _titeLabel.text = steps[_step];
        if (_step == 2) //enhance?
        {
            _bSlider.value = brightness;
            _cSlider.value = contrast;
            _briLabel.text = [NSString stringWithFormat:@"Brightness %3.2f",brightness];
            _conLabel.text = [NSString stringWithFormat:@"Contrast   %3.2f",contrast];
            if (removeColor)
            {
                [_removeColorButton setTitle:@"Restore Color" forState:UIControlStateNormal];
            }
            else
            {
                [_removeColorButton setTitle:@"Remove Color" forState:UIControlStateNormal];
            }

        }
    }
    

    //Show / hide stuff based on step and states...
    _rotateView.hidden  = (_step != 1);
    _loadButton.hidden  = (_step < 1);
    _nextButton.hidden  = (_step < 1);
    _gridOverlay.hidden = !(showRotatedImage && _step == 1);
    _enhanceView.hidden = (_step < 2);

    if (!showRotatedImage)
    {
        _templateImage.image = _photo;
    }
    else
    {
        _templateImage.image = _rphoto;
    }
    [self scaleImageViewToFitDocument];

} //end updateUI



//=============AddTemplate VC=====================================================
-(void) resetRotation
{
    rotAngle = 0.0; //Degrees
    showRotatedImage = FALSE;
}

//=============AddTemplate VC=====================================================
-(void) rotateTemplatePhoto : (double) aoff
{
    rotAngle +=aoff;
    rotAngleRadians = 3.141592627 * (float)rotAngle / 180.0  ;
    
    _rphoto =  [it imageRotatedByRadians:rotAngleRadians img:_photo];
    showRotatedImage = TRUE;
    _step = 1;
    [self updateUI];

}


//=============AddTemplate VC=====================================================
-(void) displayPhotoPicker
{
    //NSLog(@" photo picker...");
    UIImagePickerController *imgPicker;
    imgPicker = [[UIImagePickerController alloc] init];
    imgPicker.allowsEditing = NO;
    imgPicker.delegate      = self;
    imgPicker.sourceType    = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    [self presentViewController:imgPicker animated:NO completion:nil];
} //end displayPhotoPicker

//=============AddTemplate VC=====================================================
// OK? load / process image as needed
- (void)imagePickerController:(UIImagePickerController *)Picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    //Makes poppy squirrel sound!
    NSLog(@" ok...");
    _step = 1;
    //[_sfx makeTicSoundWithPitchandLevel:7 :70 : 40];
    [Picker dismissViewControllerAnimated:NO completion:^{
        self->_photo = (UIImage *)[info objectForKey:UIImagePickerControllerOriginalImage ];
        self->photoPixWid = self->_photo.size.width;
        self->photoPixHit = self->_photo.size.height;
        self->photoScreenWid = self->_templateImage.frame.size.width;
        self->photoScreenHit = self->_templateImage.frame.size.height;
        self->photoToUIX = (float)self->photoScreenWid/(float)self->_photo.size.width;
        self->photoToUIY = (float)self->photoScreenHit/(float)self->_photo.size.height;
        self->gotPhoto = TRUE;
        [self resetRotation];
        [self updateUI];
    }];
} //end didFinishPickingMediaWithInfo

//==========createVC=================================================================
// Dismiss back to parent on cancel...
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)Picker
{
    [Picker dismissViewControllerAnimated:NO completion:nil];
    if (!gotPhoto) //No Photo -> Just bouncing back out? Dismiss this VC too
        [self dismissViewControllerAnimated : YES completion:nil];
    
} //end imagePickerControllerDidCancel

//=========-createVC=========================================================================
-(void) getProcessedImageBkgd
{
    if (enhancing) return;

    // _createButton.hidden = TRUE;
    [spv start : @"Process PDF..."];
    UIImage *inputImage = _photo;
    if (showRotatedImage) inputImage = _rphoto;
    enhancing = TRUE;
    coreImage = [coreImage initWithImage:inputImage];
    NSLog(@" process bcs %f %f %f",brightness,contrast,saturation);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       dispatch_sync(dispatch_get_main_queue(), ^{
                           float cont_intensity  = self->contrast;   // some are 0 - 1, some are 0-2
                           float sat_intensity   = self->saturation;
                           float brit_intensity  = self->brightness;
                           NSNumber *workNumCont = [NSNumber numberWithFloat:cont_intensity];
                           NSNumber *workNumSat  = [NSNumber numberWithFloat:sat_intensity];
                           NSNumber *workNumBrit = [NSNumber numberWithFloat:brit_intensity];
                           CIFilter *filterCont  = [CIFilter filterWithName:@"CIColorControls"
                                                              keysAndValues: kCIInputImageKey, self->coreImage,
                                                    @"inputBrightness", workNumBrit,
                                                    @"inputSaturation", workNumSat,
                                                    @"inputContrast",   workNumCont,
                                                    nil];
                           CIImage *workCoreImage = [filterCont outputImage];
                           CIContext *context = [CIContext contextWithOptions:nil];
                           CGImageRef cgimage = [context createCGImage:workCoreImage fromRect:[workCoreImage extent] format:kCIFormatRGBA8 colorSpace:CGColorSpaceCreateDeviceRGB()];
                           self->_prphoto = [UIImage imageWithCGImage:cgimage scale:0 orientation:[self->_photo imageOrientation]];
                           CGImageRelease(cgimage);
                           [self->spv stop];
                           //[self handleProcessedResults];
                           //OK we got our image, show it!
                           self->_templateImage.image = self->_prphoto;
//                           self->_needProcessedImage = FALSE;
                           self->enhancing = FALSE;
                           [context clearCaches];
                       });
                       
                   }
                   ); //END outside dispatch
    
} //end getProcessedImageBkgd

//=============AddTemplate VC=====================================================
- (IBAction)bSliderChanged:(id)sender
{
    UISlider *s = (UISlider*)sender;
    brightness = s.value;
    [self getProcessedImageBkgd];
    _briLabel.text = [NSString stringWithFormat:@"Brightness %3.2f",brightness];

}

//=============AddTemplate VC=====================================================
- (IBAction)cSliderChanged:(id)sender
{
    UISlider *s = (UISlider*)sender;
    contrast = s.value;
    [self getProcessedImageBkgd];
    _conLabel.text = [NSString stringWithFormat:@"Contrast   %3.2f",contrast];
}


//=============AddTemplate VC=====================================================
- (IBAction)removeColorSelect:(id)sender
{
    removeColor = !removeColor;
    if (removeColor)
    {
        saturation = 0.0;
        [_removeColorButton setTitle:@"Restore Color" forState:UIControlStateNormal];
    }
    else
    {
        saturation = 1.0;
        [_removeColorButton setTitle:@"Remove Color" forState:UIControlStateNormal];
    }
    [self getProcessedImageBkgd];


} //end removeColorSelect



//=============AddTemplate VC=====================================================
-(void) clearTemplateMessage
{
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Template already exists..."
                                 message:@"Do you want to overwrite this template?"
                                 preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction
                      actionWithTitle:@"OK"
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction * action) {
                          [self getTemplatePDFFiles];
                      }]];
    [alert addAction:[UIAlertAction
                      actionWithTitle:@"Cancel"
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction * action) {
                          [self dismiss];
                      }]];
    [self presentViewController:alert animated:YES completion:nil];
} //end alertMessage





#pragma mark - DropboxToolsDelegate

//===========<DropboxToolDelegate>================================================
// We now have PDF list, goto chooser ..
- (void)didGetFolderList : (NSArray *)entries
{
    NSLog(@" files %@",entries);
    fileEntries = [NSMutableArray arrayWithArray:entries];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self choiceMenu];
    });

}

//===========<DropboxToolDelegate>================================================
- (void)errorGettingFolderList : (NSString *)s
{
    NSLog(@" errorGettingFolderList %@",s);
}

//===========<DropboxToolDelegate>================================================
- (void)didDownloadImages
{
    NSLog(@" ...got image");
    _photo   = dbt.batchImages[0];
    gotPhoto = TRUE;
    _step    = 1; //Set UI state...


    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
        [self resetRotation];
        [self updateUI];
    });
}

//===========<DropboxToolDelegate>================================================
- (void)errorDownloadingImages : (NSString *)s
{
    NSLog(@" ..error dloading template %@",s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->spv stop];
    });

}


#pragma mark - OCRTemplateDelegate


//===========<OCRTemplateDelegate>===============================================
- (void)didCheckTemplate : (int) count
{
    NSLog(@" didCheckTemplate, count %d",count);
    [spv stop];
    if (count == 0) //no template? proceed!
    {
        [self getTemplatePDFFiles];
    }
    else
    {
        [self clearTemplateMessage]; //Prompt user to overwrite template
    }
}

//===========<OCRTemplateDelegate>===============================================
- (void)errorCheckingTemplate : (NSString *)errmsg
{
    
}


@end
