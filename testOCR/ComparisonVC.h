//
//                                        _              __     ______
//    ___ ___  _ __ ___  _ __   __ _ _ __(_)___  ___  _ _\ \   / / ___|
//   / __/ _ \| '_ ` _ \| '_ \ / _` | '__| / __|/ _ \| '_ \ \ / / |
//  | (_| (_) | | | | | | |_) | (_| | |  | \__ \ (_) | | | \ V /| |___
//   \___\___/|_| |_| |_| .__/ \__,_|_|  |_|___/\___/|_| |_|\_/  \____|
//                      |_|
//
//  ComparisonVC.h
//  testOCR
//
//  Created by Dave Scruton on 2/1/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "ActivityTable.h"
#import "AppDelegate.h"
#import "DropboxTools.h"
#import "EXPStats.h"
#import "EXPTable.h"
#import "smartProducts.h"
#import "spinnerView.h"
#import "Vendors.h"

#define MAX_CVENDORS 64   //Expand as needed
#define MAX_CCATEGORIES 16 //Expand as needed

@interface ComparisonVC : UIViewController <UITableViewDelegate,UITableViewDataSource,
                                DropboxToolsDelegate,EXPTableDelegate>
{
    DropboxTools *dbt;
    EXPTable *et;
    ActivityTable *act;
    Vendors *vv;
    smartProducts *smartp;

    NSMutableArray *fileNames;
    NSArray *csvEntries;  //Fetched list of CSV files from batch folder
    spinnerView *spv;
    NSString *comparisonFolderPath;
    NSString *comparisonFilePath;
    NSArray *pamHeaders;
    NSArray *pamKeywords;
    NSMutableArray *columnKeys;
    
    NSMutableArray *monthlyStats;
    
    
    int writeCount,okCount,errCount,loadCount;

    
}
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *table;

- (IBAction)backSelect:(id)sender;

@end

