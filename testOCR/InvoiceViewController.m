//
//   _                 _        __     ______
//  (_)_ ____   _____ (_) ___ __\ \   / / ___|
//  | | '_ \ \ / / _ \| |/ __/ _ \ \ / / |
//  | | | | \ V / (_) | | (_|  __/\ V /| |___
//  |_|_| |_|\_/ \___/|_|\___\___| \_/  \____|
//
//  InvoiceViewController.m
//  testOCR
//
//  Created by Dave Scruton on 1/14/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  2/6 add segue to PDFVC
//  2/9 add parentUp to invoiceTable
//  2/22 add loadingData flag
//  3/22 debug pass multi-customers
//  4/5  add sfx, only support ONE vendor at a time

#import "InvoiceViewController.h"



@implementation InvoiceViewController

//=============Invoice VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    it    = [[invoiceTable alloc] init];
    it.delegate = self;
    iobj  = [[invoiceObject alloc] init];   //For selecting single invoices
    iobjs = [[NSMutableArray alloc] init];  // ...all invoices loaded into VC
    pc    = [PDFCache sharedInstance];      //For looking at images of ivoices
    vv    = [Vendors sharedInstance];
    // 4/5 sfx
    _sfx         = [soundFX sharedInstance];

    return self;
}

//=============Invoice VC=====================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    _table.delegate   = self;
    _table.dataSource = self;

    // 1/19 Add spinner busy indicator...
    CGSize csz   = [UIScreen mainScreen].bounds.size;
    spv = [[spinnerView alloc] initWithFrame:CGRectMake(0, 0, csz.width, csz.height)];
    [self.view addSubview:spv];

    if (_vendor == nil) //Default to HFM on err
    {
        NSLog(@" ERROR:InvoiceVC: Nil Vendor! ");
        _vendor = @"HFM";
    }
    _titleLabel.text  = @"Loading Invoices...";
    loadingData = TRUE;
    [spv start : @"Loading Invoices"];
    [it readFromParseAsStrings : _vendor  : @"*" : _invoiceNumber];

} //end viewDidLoad


//=============Invoice VC=====================================================
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

//=============Invoice VC=====================================================
-(void) makeCancelSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 82];
}


//=============Invoice VC=====================================================
-(void) makeSegueSound
{
    [self->_sfx makeTicSoundWithPitch : 4 : 84];
    [self->_sfx makeTicSoundWithPitch : 4 : 89];
    [self->_sfx makeTicSoundWithPitch : 4 : 96];
}

//=============Invoice VC=====================================================
-(void) makeSelectSound
{
    [self->_sfx makeTicSoundWithPitch : 5 : 70];
}

//=============Invoice VC=====================================================
-(void) finishedLoadingVendorInvoices
{
    loadingData = FALSE;
    [spv stop];
    [_table reloadData];
    NSString *s;
    //4/5 redid yet again!
    if (![_vendor isEqualToString:@"*"])
        s = [NSString stringWithFormat:@"Invoices: %@",_vendor];
    else if (![_batchID isEqualToString:@"*"]) //Specific batch?
        s = [NSString stringWithFormat:@"Invoices:Batch %@",_batchID];
    else if (![_invoiceNumber isEqualToString:@"*"]) //Specific invoice #?
        s = [NSString stringWithFormat:@"Invoice:%@",_invoiceNumber];
    _titleLabel.text  = s;

} //end finishedLoadingVendorInvoices

//=============Invoice VC=====================================================
// 4/5 obsolete?
-(void) loadNextVendorInvoice
{
    if (vptr >= vv.vcount) //All done??
    {
        [self finishedLoadingVendorInvoices];
 
        return;
    }
    NSString* vname = [vv getNameByIndex:vptr];  //DHS 3/6
    NSLog(@"  ...load next vendor %@",vname);
    [it readFromParseAsStrings : vname : _batchID : _invoiceNumber]; //3/22 add batchID
    vptr++;
} //end loadNextVendorInvoice



//=============Invoice VC=====================================================
-(void) dismiss
{
    [self makeCancelSound];
    it.parentUp = FALSE; // 2/9 Tell invoiceTable we are outta here
    [self dismissViewControllerAnimated : YES completion:nil];
}

//=============Invoice VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}


//=============OCR MainVC=====================================================
// For select function from table
-(void) funcmenu
{
    NSMutableAttributedString *tatString = [[NSMutableAttributedString alloc]initWithString:@"Invoice Function"];
    [tatString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:25] range:NSMakeRange(0, tatString.length)];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:
                                NSLocalizedString(@"Invoice Function",nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert setValue:tatString forKey:@"attributedTitle"];
    
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Load EXP Table",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   [self performSegueWithIdentifier:@"invoiceDetailSegue" sender:@"invoiceVC"];
                                               }]];
    [alert addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"Load PDF Images",nil)
                                               style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                   [self makeSelectSound];
                                                   NSString *pf  = self->iobj.PDFFile;
                                                   self->selPage = self->iobj.page;
                                                  //2/10 test if ([self->pc imageExistsByID:pf : 1])
                                                   {
                                                       self->selFname = pf;
                                                       [self performSegueWithIdentifier:@"pdfSegue" sender:@"invoiceVC"];
                                                   }
                                               }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self makeCancelSound];
                                                           }]];
    [self presentViewController:alert animated:YES completion:nil];
} //end funcmenu


#pragma mark - UITableViewDelegate


//=============Invoice VC=====================================================
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    int row = (int)indexPath.row;
    invoiceCell *cell = (invoiceCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[invoiceCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    iobj = iobjs[row];
    cell.label1.text = [NSString stringWithFormat:@"Vendor:%@:Batch:%@",_vendor,iobj.batchID] ;
    NSDateFormatter * formatter =  [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MM/dd/yyyy"];
    NSString *sfd = [formatter stringFromDate:iobj.date];
    cell.label2.text = [NSString stringWithFormat:@"...Number:%@:Date:%@",iobj.invoiceNumber,sfd] ;

    return cell;
} //end cellForRowAtIndexPath


//=============Invoice VC=====================================================
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (int)iobjs.count;
}

//=============Invoice VC=====================================================
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}


//=============Invoice VC=====================================================
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self makeSelectSound];
    selectedRow = (int)indexPath.row;
    iobj = iobjs[selectedRow];
    [self funcmenu];
}


//=============Invoice VC=====================================================
// Handles last minute VC property setups prior to segues
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //NSLog(@" prepareForSegue: %@ sender %@",[segue identifier], sender);
    [self makeSegueSound];
    if([[segue identifier] isEqualToString:@"invoiceDetailSegue"])
    {
        EXPViewController *vc = (EXPViewController *)[segue destinationViewController];
        vc.detailMode = TRUE;
        vc.searchType = _vendor; //Multiple uses for searchType!
        vc.actData    = iobj.batchID;
        vc.invoiceNumber = iobj.invoiceNumber;
    }
    else if([[segue identifier] isEqualToString:@"pdfSegue"]) //2/6
    {
        PDFVC *vc = (PDFVC *)[segue destinationViewController];
        vc.pdfFile = selFname;
        vc.vendor  = _vendor;
        vc.page    = selPage;
        vc.invoiceNumber = iobj.invoiceNumber;
    }

}



#pragma mark - invoiceTableDelegate

//=============EXP VC=====================================================
//May come thru multiple times for vendors, add results up and go for more
- (void)didReadInvoiceTableAsStrings : (NSMutableArray*)a
{
    [iobjs addObjectsFromArray:(NSArray*)a];
    [self finishedLoadingVendorInvoices]; //DHS 4/5
    //DHS 4/5 [self loadNextVendorInvoice];
}



@end
