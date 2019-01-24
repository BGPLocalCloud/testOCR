//
//  documentBox.h
//  testOCR
//
//  Created by Dave Scruton on 1/20/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface documentBox : NSObject

@property (nonatomic , assign) CGRect frame;
@property (nonatomic , strong) NSMutableArray* items;

-(void) dump;

@end

