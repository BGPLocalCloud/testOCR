//
//  VendorObject.h
//  testOCR
//
//  Created by Dave Scruton on 3/6/19.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface VendorObject : NSObject
{

}
@property (nonatomic , strong) NSString* vName;
@property (nonatomic , strong) NSString* vNameLC;
@property (nonatomic , strong) NSString* vFolderName;
@property (nonatomic , strong) NSString* vRotation;
@property (nonatomic , strong) NSString* vIntQuantity;
@property (nonatomic , strong) NSString* vTLTemplate; //is this the best place for these 2?
@property (nonatomic , strong) NSString* vTRTemplate;

@end


