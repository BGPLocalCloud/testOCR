//
//   _______  ______  ____       _        _ ___     ______
//  | ____\ \/ /  _ \|  _ \  ___| |_ __ _(_) \ \   / / ___|
//  |  _|  \  /| |_) | | | |/ _ \ __/ _` | | |\ \ / / |
//  | |___ /  \|  __/| |_| |  __/ || (_| | | | \ V /| |___
//  |_____/_/\_\_|   |____/ \___|\__\__,_|_|_|  \_/  \____|
//
//  EXPDetailVC.m
//  testOCR
//
//  Created by Dave Scruton on 1/4/19.
//  Copyright © 2019 huedoku. All rights reserved.
//

#import "EXPDetailVC.h"

@interface EXPDetailVC ()

@end

@implementation EXPDetailVC

//=============EXPDetail VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _eobj = [_allObjects objectAtIndex:_detailIndex];
    
    UISwipeGestureRecognizer *leftGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDetectedLeft:)];
    leftGesture.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:leftGesture];
    
    UISwipeGestureRecognizer *rightGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDetectedRight:)];
    rightGesture.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:rightGesture];
    

}

//=============EXPDetail VC=====================================================
-(void) setTextFieldWithError : (UILabel *) l : (NSString *)s : (BOOL) blankIsError
{
    l.text = s;
    if ([s isEqualToString:@"$ERR"] || (blankIsError && s.length < 1))
        l.backgroundColor = [UIColor redColor];
    else
        l.backgroundColor = [UIColor clearColor];
}

//=============EXPDetail VC=====================================================
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateUI];
    
}

//=============EXPDetail VC=====================================================
-(void) updateUI
{
    _titleLabel.text = [NSString stringWithFormat:@"EXP[%@](%d/100)",_eobj.objectId,_detailIndex+1];
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy  HH:mmv:SS"];
    NSString *sfd = [formatter stringFromDate:_eobj.expdate];
    _dateLabel.text = sfd;
    [self setTextFieldWithError : _categoryLabel     : _eobj.category : TRUE];
    [self setTextFieldWithError : _monthLabel        : _eobj.month : TRUE];
    [self setTextFieldWithError : _itemLabel         : _eobj.item : TRUE];
    [self setTextFieldWithError : _uomLabel          : _eobj.uom : TRUE];
    [self setTextFieldWithError : _bulkLabel         : _eobj.bulk : TRUE];
    [self setTextFieldWithError : _vendorLabel       : _eobj.vendor : TRUE];
    [self setTextFieldWithError : _productNameLabel  : _eobj.productName : TRUE];
    [self setTextFieldWithError : _processedLabel    : _eobj.processed : TRUE];
    [self setTextFieldWithError : _localLabel        : _eobj.local : TRUE];
    [self setTextFieldWithError : _lineNumberLabel   : _eobj.lineNumber : TRUE];
    [self setTextFieldWithError : _quantityLabel     : _eobj.quantity : TRUE];
    [self setTextFieldWithError : _pricePerUOMLabel  : _eobj.pricePerUOM : TRUE];
    [self setTextFieldWithError : _totalLabel        : _eobj.total : TRUE];
    [self setTextFieldWithError : _batchLabel        : _eobj.batch : TRUE];
    [self setTextFieldWithError : _pdfFileLabel      : _eobj.PDFFile : TRUE];
    int aoc = (int)_allObjects.count;
    if (aoc > 0) [_progressView setProgress:(float)_detailIndex/(float)aoc];
} //end updateUI

//=============EXPDetail VC=====================================================
- (void)swipeDetectedRight:(UISwipeGestureRecognizer *)sender
{
    //Access previous cell in TableView
    if (_detailIndex != 0) // This way it will not go negative
        _detailIndex--;
    _eobj = [_allObjects objectAtIndex:_detailIndex];
    [self updateUI];
}


//=============EXPDetail VC=====================================================
- (void)swipeDetectedLeft:(UISwipeGestureRecognizer *)sender
{
    //Access next cell in TableView
    if (_detailIndex != [_allObjects count]) // make sure that it does not go over the number of objects in the array.
        _detailIndex++;  // you'll need to check bounds
    _eobj = [_allObjects objectAtIndex:_detailIndex];
    [self updateUI];
}

//=============EXPDetail VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}


//=============EXPDetail VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}

@end
