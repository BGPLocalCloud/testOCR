//
//   _                 _        __     ______
//  (_)_ ____   _____ (_) ___ __\ \   / / ___|
//  | | '_ \ \ / / _ \| |/ __/ _ \ \ / / |
//  | | | | \ V / (_) | | (_|  __/\ V /| |___
//  |_|_| |_|\_/ \___/|_|\___\___| \_/  \____|
//
//  InvoiceViewController.h
//  testOCR
//
//  Created by Dave Scruton on 1/14/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBKeys.h"
#import "EXPViewController.h"
#import "invoiceCell.h"
#import "OCRWord.h"
#import "invoiceObject.h"
#import "invoiceTable.h"
#import "spinnerView.h"
#import "PDFCache.h"
#import "PDFVC.h"
#import "Vendors.h"
#import "soundFX.h"

NS_ASSUME_NONNULL_BEGIN

@interface InvoiceViewController : UIViewController <UITableViewDelegate,UITableViewDataSource,
                                    invoiceTableDelegate>
{
    invoiceTable *it;
    invoiceObject *iobj;
    NSMutableArray *iobjs;
    PDFCache *pc;
    Vendors *vv;
    int vptr;
    int selectedRow;
    spinnerView *spv;
    BOOL loadingData;

    NSString *selFname;
    NSString *selNumber;
    NSString *selPage; //4/5
}

- (IBAction)backSelect:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *table;
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (nonatomic, strong) soundFX *sfx;

@property (nonatomic , strong) NSString* vendor;
@property (nonatomic , strong) NSString* batchID;
@property (nonatomic , strong) NSString* invoiceNumber;

@end

NS_ASSUME_NONNULL_END
