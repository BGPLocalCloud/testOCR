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

#import "InvoiceViewController.h"

@interface InvoiceViewController ()

@end

@implementation InvoiceViewController

//=============Invoice VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    it = [[invoiceTable alloc] init];
    it.delegate = self;
    iobj  = [[invoiceObject alloc] init];   //For selecting single invoices
    iobjs = [[NSMutableArray alloc] init];  // ...all invoices loaded into VC
    pc    = [PDFCache sharedInstance];      //For looking at images of ivoices
    vv    = [Vendors sharedInstance];
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

    if (_vendor == nil) //SHOULD NEVER HAPPEN
    {
        NSLog(@" ERROR:InvoiceVC: Nil Vendor! ");
        _vendor = @"*";
    }
    _titleLabel.text  = @"Loading Invoices...";
    [spv start : @"Loading Invoices"];
    if ([_vendor isEqualToString:@"*"]) //Get all vendors
    {
        vptr = 0;
        [self loadNextVendorInvoice];
    }
    else
    {
        [it readFromParseAsStrings : _vendor  : @"*" : _invoiceNumber];
    }

} //end viewDidLoad

//=============Invoice VC=====================================================
-(void) loadNextVendorInvoice
{
    if (vptr >= vv.vNames.count) //All done??
    {
        [spv stop];
        [_table reloadData];
        NSString *s;
        //2/8 redid
        if (![_batchID isEqualToString:@"*"])
        {
            s = [NSString stringWithFormat:@"Invoices:Batch %@",_batchID];
        }
        else if (![_vendor isEqualToString:@"*"])
            s = [NSString stringWithFormat:@"Invoices:Vendor %@",_vendor];
        else if (![_invoiceNumber isEqualToString:@"*"])
            s = [NSString stringWithFormat:@"Invoice:%@",_invoiceNumber];
        else
        {
            s =  @"All Invoices";
        }
        _titleLabel.text  = s;

        return;
    }
    NSString*vname = vv.vNames[vptr];
    //NSLog(@"  ...load next vendor %@",vname);
    [it readFromParseAsStrings : vname : @"*" : _invoiceNumber];
    vptr++;
} //end loadNextVendorInvoice



//=============Invoice VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
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
                                                   NSString *pf = self->iobj.PDFFile;
                                                   if ([self->pc imageExistsByID:pf : 1])
                                                   {
                                                       self->selFname = pf;
                                                       NSLog(@" got image...");
                                                       [self performSegueWithIdentifier:@"pdfSegue" sender:@"invoiceVC"];
                                                   }
                                               }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
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
    if ([_vendor isEqualToString:@"*"]) //This isn't set up yet!
        cell.label1.text = [NSString stringWithFormat:@"Vendor:%@:Batch:%@",iobj.vendor,iobj.batchID] ;
    else //2/6
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
    selectedRow = (int)indexPath.row;
    iobj = iobjs[selectedRow];
    [self funcmenu];
}


//=============Invoice VC=====================================================
// Handles last minute VC property setups prior to segues
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //NSLog(@" prepareForSegue: %@ sender %@",[segue identifier], sender);
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
        vc.invoiceNumber = iobj.invoiceNumber;
    }

}



#pragma mark - invoiceTableDelegate

//=============EXP VC=====================================================
- (void)didReadInvoiceTableAsStrings : (NSMutableArray*)a
{
    [iobjs addObjectsFromArray:(NSArray*)a];
    [self loadNextVendorInvoice];
}

@end
