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

#import "InvoiceViewController.h"

@interface InvoiceViewController ()

@end

@implementation InvoiceViewController

//=============Invoice VC=====================================================
-(id)initWithCoder:(NSCoder *)aDecoder {
    if ( !(self = [super initWithCoder:aDecoder]) ) return nil;
    
    it = [[invoiceTable alloc] init];
    it.delegate = self;
    iobj = [[invoiceObject alloc] init];
    
    iobjs = [[NSMutableArray alloc] init];

    vv  = [Vendors sharedInstance];

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

    _titleLabel.text  = @"Loading Invoices...";
    [spv start : @"Loading Invoices"];
    if ([_vendor isEqualToString:@"*"]) //Get all vendors
    {
        vptr = 0;
        [self loadNextVendorInvoice];
    }
    else
    {
        [it readFromParseAsStrings : @"HFM"  : @"*"];
    }

} //end viewDidLoad

//=============Invoice VC=====================================================
-(void) loadNextVendorInvoice
{
    if (vptr >= vv.vNames.count) //All done??
    {
        [spv stop];
        [_table reloadData];
        if (!_vendor || [_vendor isEqualToString:@"*"]) //Get all vendors
            _titleLabel.text  = @"Invoices for all Vendors";
        else
        {
            _titleLabel.text = [NSString stringWithFormat:@"Invoices:%@",_vendor] ;
        }
        return;
    }
    NSString*vname = vv.vNames[vptr];
    //NSLog(@"  ...load next vendor %@",vname);
    [it readFromParseAsStrings : vname : @"*"];
    vptr++;
} //end loadNextVendorInvoice



//=============Invoice VC=====================================================
-(void) dismiss
{
    //[_sfx makeTicSoundWithPitch : 8 : 52];
    [self dismissViewControllerAnimated : YES completion:nil];
    
}

//=============Invoice VC=====================================================
- (IBAction)backSelect:(id)sender
{
    [self dismiss];
}



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
    cell.label1.text = [NSString stringWithFormat:@"Vendor:%@",iobj.vendor] ;
    cell.label2.text = [NSString stringWithFormat:@"Number:%@:Batch:%@",iobj.invoiceNumber,iobj.batchID] ;

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
    [self performSegueWithIdentifier:@"invoiceDetailSegue" sender:self];
    
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
        vc.searchType = iobj.vendor; //Multiple uses for searchType!
        vc.actData    = iobj.batchID;
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
