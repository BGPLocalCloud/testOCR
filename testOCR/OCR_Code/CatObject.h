//
//  CatObject.h
//  testOCR
//
//    ____      _    ___  _     _           _
//   / ___|__ _| |_ / _ \| |__ (_) ___  ___| |_
//  | |   / _` | __| | | | '_ \| |/ _ \/ __| __|
//  | |__| (_| | |_| |_| | |_) | |  __/ (__| |_
//   \____\__,_|\__|\___/|_.__// |\___|\___|\__|
//                            |__/
//
//  Created by Dave Scruton on 12/19/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CatObject : NSObject
{
    
}
@property (nonatomic , strong) NSString* category;
@property (nonatomic , strong) NSString* item;
@property (nonatomic , strong) NSString* processed;
@property (nonatomic , strong) NSString* local;
@property (nonatomic , strong) NSString* uom;
@property (nonatomic , assign) BOOL isProcessed;
@property (nonatomic , assign) BOOL isLocal;

- (id) initWithCategory : (NSString*) c : (NSString*) i : (NSString*) p : (NSString*) l : (NSString*) u;


@end

