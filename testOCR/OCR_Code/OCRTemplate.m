//
//    ___   ____ ____ _____                    _       _
//   / _ \ / ___|  _ \_   _|__ _ __ ___  _ __ | | __ _| |_ ___
//  | | | | |   | |_) || |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \
//  | |_| | |___|  _ < | |  __/ | | | | | |_) | | (_| | ||  __/
//   \___/ \____|_| \_\|_|\___|_| |_| |_| .__/|_|\__,_|\__\___|
//                                      |_|
//
//  OCRTemplate.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
//  4/1 add loadTemplateFromPFObject

#import "OCRTemplate.h"

@implementation OCRTemplate

#define INVOICE_TOP_LIMITS_LABEL @"INVOICE_TOP_LIMITS"


//=============(OCRTemplate)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        documentsDirectory = [paths objectAtIndex:0];
        ocrBoxes      = [[NSMutableArray alloc] init];
        _versionNumber    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        recordStrings = [[NSMutableArray alloc] init]; //Invoice string results
        orientationWhenReadable = @"portrait";
        _pdfFile = @"";
        //NSLog(@" init template, orient %@",orientationWhenReadable);
        //[self dump];
    }
    return self;
}

//=============(OCRTemplate)=====================================================
-(void) clearFields
{
    NSLog(@" clear document template...");
    [ocrBoxes removeAllObjects];
}

//=============(OCRTemplate)=====================================================
-(void) clearHeaders
{
    for (int i=0;i<32;i++)
    {
        headerColumns[i] = CGRectMake(0, 0, 0, 0);
        headerTypes[i]   = @"";
    }
    
    headerColumnCount = 0;
}

//=============(OCRTemplate)=====================================================
-(void) clearTags : (int) index
{
    if (index < 0 || index >= ocrBoxes.count) return;
    OCRBox* ob = [ocrBoxes objectAtIndex:index];
    [ob clearTags];
}

//=============(OCRTemplate)=====================================================
-(void) deleteBox : (int) index
{
    [ocrBoxes removeObjectAtIndex:index];
}

//=============(OCRTemplate)=====================================================
-(int) firstColumn
{
    int i = 0;
    for (OCRBox *ob in ocrBoxes)
    {
        if ([ob.fieldName isEqualToString : INVOICE_COLUMN_FIELD]) return i;
        i++;
    }
    return -1;
}

//=============(OCRTemplate)=====================================================
// Was called by cleanupColumns, which is now stubbed
-(int) getColumnXRanges
{
    int count;
    //Set up pre-ordered column x expanses...
    for (count=0;count<32;count++)
    {
        cxrange1[count] = cxrange2[count] = cptrs[count] = 0;
    }
    int cptr=0;
    for (count=0;count < ocrBoxes.count;count++)
    {
        OCRBox *ob1 = ocrBoxes[count];
        if ([ob1.fieldName isEqualToString : INVOICE_COLUMN_FIELD])
        {
            cxrange1[cptr] = ob1.frame.origin.x;
            cxrange2[cptr] = ob1.frame.origin.x + ob1.frame.size.width;
            cptrs[cptr]  = count;
            cptr++;
        }
    }
    maxcptr = cptr;
    return cptr; //Return our final column count
} //end getColumnXRanges

//=============(OCRTemplate)=====================================================
// Double check column alignment and prevent overlaps... assumes pre-ordered!
-(void) cleanupColumns
{
    //THERE IS A BUG; FIX BEFORE USING THIS!
#ifdef CLEANUPCOLUMNS_BUG_IS_FIXED
    //Somehow it had 2 good columns but then collapsed the RH one onto the LH one!
    //  and the newWid came out NEGATIVE!
    if ([self getColumnXRanges] < 2) return; //Not enuf columns to check!
    for (int i=0;i < maxcptr-1;i++)
    {
        int testl = cxrange2[i];
        int testr = cxrange1[i+1];
        if (testl >= testr) //OVERLAP! fix column to left
        {
            //adjust this column!
            NSLog(@" ....fix overlap! col %d vs %d",i,i+1);
            int cptr = cptrs[i];
            OCRBox *ob1 = ocrBoxes[cptr]; //Get box to fix...
            int xleft = ob1.frame.origin.x;
            int newWid = testr - 1 - xleft;
            NSLog(@"  ..fix colunn %d [%d] :x [%d] newwid %d",i,cptr,xleft,newWid);
            ob1.frame = CGRectMake(ob1.frame.origin.x, ob1.frame.origin.y, newWid, ob1.frame.size.height);
            ocrBoxes[cptr] = ob1; //Re-insert fixed box
        }
    } //end for count
#endif
} //end cleanupColumns

//=============(OCRTemplate)=====================================================
-(void) addBox : (CGRect) frame : (NSString *)fname : (NSString *)format
{
    NSLog(@" clear document template...");
    OCRBox *ob = [[OCRBox alloc] init];
    if (frame.origin.x < 0) frame.origin.x = 0; //Don't allow off-document frmaes!
    if (frame.origin.y < 0) frame.origin.y = 0;
    
    //2/15 compare against multiple column types
    if ([@[INVOICE_COLUMN_FIELD,INVOICE_COLUMN_ITEM_FIELD,INVOICE_COLUMN_DESCRIPTION_FIELD,
           INVOICE_COLUMN_QUANTITY_FIELD,INVOICE_COLUMN_PRICE_FIELD ,INVOICE_COLUMN_AMOUNT_FIELD]
         containsObject: fname]) //Column? get which one?
    {
        int fcindex = [self firstColumn];
        if (fcindex >= 0) //2nd...column? just line up w/ first
        {
            OCRBox *ob = [ocrBoxes objectAtIndex:fcindex];
            frame.origin.y    = ob.frame.origin.y;      // Match Top
            frame.size.height = ob.frame.size.height;  // Match Top
            NSLog(@" match column top/bottom...");
        }
    }
    ob.frame = frame;
    ob.fieldName = fname;
    ob.fieldFormat = format;
    [ocrBoxes addObject:ob];
} //end addBox

//=============(OCRTemplate)=====================================================
-(void) addTag : (int) index : (NSString*)tag
{
    OCRBox *ob = ocrBoxes[index];
    [ob addTag:tag];
} //end addTag

//=============(OCRTemplate)=====================================================
// New arg: headerY, just below found position of actual header in doc coords
-(void) addHeaderColumnToSortedArray : (int) index : (NSString *)columnType : (int) y
{
    headerY = y;
    OCRBox *ob = ocrBoxes[index];
    int xleft =  ob.frame.origin.x;
    int whereToAdd = headerColumnCount;
    for (int i=0;i<headerColumnCount;i++)
    {
        CGRect rr = headerColumns[i];
        if (xleft < rr.origin.x)  //Found a header to left of this one? insert...
        {
            //for (int j=i+1;j<headerColumnCount+1;j++)
            for (int j=headerColumnCount;j>i;j--)
            {
                headerColumns[j] = headerColumns[j-1];
                headerTypes[j]   = headerTypes[j-1];
            }
            whereToAdd = i;
            break;
        }
    }
    //NSLog(@" where %d rect %@",whereToAdd,NSStringFromCGRect(ob.frame));
    headerColumns[whereToAdd] = ob.frame;   //OK add it
    headerTypes[whereToAdd]   = columnType; //OK add it
    headerColumnCount++;
    //NSLog(@" addhc %d , count %d",index,headerColumnCount);

} //end addHeaderColumnToSortedArray


//=============(OCRTemplate)=====================================================
// 3/17 See if we have vendors template asdf
-(void) checkVendorTemplate : (NSString *)vendorMatch
{
    PFQuery *query = [PFQuery queryWithClassName:@"templates"];
    [query whereKey:@"vendor" equalTo:vendorMatch];
    [query countObjectsInBackgroundWithBlock:^(int count, NSError *error) {
        //        NSLog(@" find puzzles matching %@",matchString);
        if (!error) { //Query came back...
            [self.delegate didCheckTemplate : count]; //Pass count back to delegate
        }
        else{
            [self.delegate errorCheckingTemplate : error.localizedDescription];
        }
    }]; //end query
} //end checkVendorTemplate



//=============(OCRTemplate)=====================================================
// which item in he
-(CGRect) getColumnRect :(int) index
{
    if (index < 0 || index > 31) return CGRectZero;
    return headerColumns[index];
}

//=============(OCRTemplate)=====================================================
-(NSString *) getColumnType : (int) column
{
    if (column < 0 || column > 31) return @"";
    return headerTypes[column];
}



//=============(OCRTemplate)=====================================================
-(void) dumpBox : (int) index
{
    NSLog(@"Dump Template Box[%d]...",index);
    OCRBox* ob = [ocrBoxes objectAtIndex:index];
    [ob dump];
} //end dumpBox


//=============(OCRTemplate)=====================================================
-(void) dump
{
    NSLog(@"Dump Template...");
    int i = 0;
    for (OCRBox *ob in ocrBoxes)
    {
        NSLog(@"t[%d]",i);
        i++;
        [ob dump];
    }
} //end dump

//=============(OCRTemplate)=====================================================
-(int) hitField :(int) tx : (int) ty
{
    int index = 0;
    for (OCRBox *ob in ocrBoxes)
    {
        CGRect r = ob.frame;
        if (
            tx >= r.origin.x && tx <= r.origin.x+r.size.width &&
            ty >= r.origin.y && ty <= r.origin.y+r.size.height
            ) return index;
        index++;
    }
    return -1;
}

//=============(OCRTemplate)=====================================================
// Used to parse incoming template settings
-(CGRect) getRectFromStringItems : (NSArray*)sitems : (int) ptr
{
    int xi,yi,xs,ys;
    NSString *ss = sitems[ptr++];
    xi = [ss intValue];
    if (xi < 0) xi = 0; //Err check: should never occor
    ss = sitems[ptr++];
    yi = [ss intValue];
    if (yi < 0) yi = 0; //Err check: should never occor
    ss = sitems[ptr++];
    xs = [ss intValue];
    ss = sitems[ptr++];
    ys = [ss intValue];
    return CGRectMake(xi, yi, xs, ys);
}

//=============(OCRTemplate)=====================================================
// assumes string is OK!
-(void) unpackFromString : (NSString *)s
{
    //NSLog(@" unpack [%@]",s);
    [ocrBoxes removeAllObjects];
    NSArray *sitems =  [s componentsSeparatedByString:@";"];
    for (NSString *substr in sitems)
    {
        NSArray *titems =  [substr componentsSeparatedByString:@","];
        //First we have a header with general info...
        if ([titems[0] isEqualToString:INVOICE_TOP_LIMITS_LABEL]) //Look for top limits
             {
                 NSLog(@" parse rect...");
                 int ptr = 1;
                 orientationWhenReadable = titems[ptr++];
                 CGRect rr1 = [self getRectFromStringItems:titems :ptr];
                 CGRect rr2 = [self getRectFromStringItems:titems :ptr+4];
                 if (rr1.size.width > 0) //Only handle valid rects?
                 {
                     tlDocRect = rr1;
                     trDocRect = rr2;
                 }
                 //NSLog(@"  tl/tr rects %@ to %@",NSStringFromCGRect(rr1),NSStringFromCGRect(rr2));
             }
        else if (titems.count >= 6) //Legal only please...
        {
            OCRBox *ob = [[OCRBox alloc] init];
            int ptr = 0;
            ob.fieldName   = titems[ptr++];
            ob.fieldFormat = titems[ptr++];
            ob.frame = [self getRectFromStringItems:titems :ptr];
            NSString *ss;
            ptr+=4;
            if (titems.count > 6) //Got tags?
            {
                ss = titems[ptr++];
                NSArray *tagItems =  [ss componentsSeparatedByString:@":"];
                for (int i=1;i<tagItems.count;i++) [ob addTag:[tagItems objectAtIndex:i]];
            }
            //NSLog(@" ..add box %d,%d",xi,yi);
            if (![self isDupeFrame:ob.frame]) [ocrBoxes addObject:ob];
        }
    }
    //NSLog(@" unpacked %d items",(int)ocrBoxes.count);
} //end unpackFromString

//=============(OCRTemplate)=====================================================
-(BOOL) isDupeFrame : (CGRect)rrtest
{
    BOOL dupe = FALSE;
    for (OCRBox *ob in ocrBoxes)
    {
        CGRect rr = ob.frame;
        if (
            rr.origin.x    == rrtest.origin.x    &&
            rr.origin.y    == rrtest.origin.y    &&
            rr.size.width  == rrtest.size.width  &&
            rr.size.height == rrtest.size.height
            )
            return TRUE;
    }
    return dupe;
}

//=============(OCRTemplate)=====================================================
-(NSString *)packToString
{
    NSString *s = @"";
    //First pack invoice limits...
    s = [s stringByAppendingString:[NSString stringWithFormat:@"%@,%@,%d,%d,%d,%d,%d,%d,%d,%d;",
                                    INVOICE_TOP_LIMITS_LABEL,orientationWhenReadable,
                                    (int)tlDocRect.origin.x,(int)tlDocRect.origin.y,
                                    (int)tlDocRect.size.width,(int)tlDocRect.size.height,
                                    (int)trDocRect.origin.x,(int)trDocRect.origin.y,
                                    (int)trDocRect.size.width,(int)trDocRect.size.height]];

    for (OCRBox *ob in ocrBoxes)
    {
        s = [s stringByAppendingString:[NSString stringWithFormat:@"%@,",ob.fieldName]];
        s = [s stringByAppendingString:[NSString stringWithFormat:@"%@,",ob.fieldFormat]];
        CGRect r = ob.frame;
        s = [s stringByAppendingString:[NSString stringWithFormat:@"%d,%d,%d,%d",
                                        (int)r.origin.x,(int)r.origin.y,(int)r.size.width,(int)r.size.height]];
        int nt = [ob getTagCount];
        if (nt > 0)
        {
            s = [s stringByAppendingString:@",Tags:"];
            for (int i=0;i<nt;i++)
            {
                NSString*tag = [ob getTag:i];
                NSString*format = @"%@:";
                if (i == nt-1) format = @"%@;";
                s = [s stringByAppendingString:[NSString stringWithFormat:format,tag]];
            }
        }
        else
        {
            s = [s stringByAppendingString:@";"];
        }
        
    }
    NSLog(@" [%@]",s);
    return s;
} //end packToString

//=============(OCRTemplate)=====================================================
-(NSString *) getAllTags :(int) index
{
    if (index < 0 || index >= ocrBoxes.count) return @"";
    OCRBox *ob = ocrBoxes[index];
    return [ob getAllTags];
}

//=============(OCRTemplate)=====================================================
-(int) getBoxCount
{
    return (int)ocrBoxes.count;
}

//=============(OCRTemplate)=====================================================
-(CGRect) getBoxRect :(int) index
{
    if (index < 0 || index >= ocrBoxes.count) return CGRectMake(0, 0, 0, 0);
    OCRBox *ob = ocrBoxes[index];
    return ob.frame;
}

//=============(OCRTemplate)=====================================================
-(NSString*) getBoxFieldName :(int) index
{
    if (index < 0 || index >= ocrBoxes.count) return @"";
    OCRBox *ob = ocrBoxes[index];
    return ob.fieldName;
}

//=============(OCRTemplate)=====================================================
-(NSString*) getBoxFieldFormat :(int) index
{
    if (index < 0 || index >= ocrBoxes.count) return @"";
    OCRBox *ob = ocrBoxes[index];
    return ob.fieldFormat;
}


//=============(OCRTemplate)=====================================================
-(int) getColumnCount
{
    return headerColumnCount;
}

//=============(OCRTemplate)=====================================================
-(CGRect) getColumnByIndex : (int) index
{
    if (index < 0 || index >= headerColumnCount) return CGRectMake(0, 0, 0, 0  );
    return headerColumns[index];
}

//=============(OCRTemplate)=====================================================
-(BOOL) gotFieldAlready : (NSString*)fname
{
    for (OCRBox *ob in ocrBoxes)
    {
        if ([fname isEqualToString:ob.fieldName]) return TRUE; //Got a match already?
    }
    return FALSE;
}

//=============(OCRTemplate)=====================================================
-(int)  getTagCount : (int) index
{
    if (index < 0 || index >= ocrBoxes.count) return 0;
    OCRBox* ob = [ocrBoxes objectAtIndex:index];
    return [ob getTagCount];
}

//=============(OCRTemplate)=====================================================
-(BOOL) isSupplierAMatch : (NSString *)stest
{
    NSString* sstr = _supplierName.lowercaseString;
    sstr = [sstr stringByReplacingOccurrencesOfString:@" " withString:@""]; //Finally NO spaces
    NSString* wstr = stest.lowercaseString;
    //Get rid of extraneous stuff...
    wstr = [wstr stringByReplacingOccurrencesOfString:@", llc" withString:@""];
    wstr = [wstr stringByReplacingOccurrencesOfString:@",llc" withString:@""];
    wstr = [wstr stringByReplacingOccurrencesOfString:@", inc" withString:@""];
    wstr = [wstr stringByReplacingOccurrencesOfString:@",inc" withString:@""];
    wstr = [wstr stringByReplacingOccurrencesOfString:@" " withString:@""]; //Finally NO spaces
    return ([sstr isEqualToString:wstr]);
}

//=============(OCRTemplate)=====================================================
-(void) loadTemplatesFromDisk : (NSString *)vendorName
{
    //Load the array if anything exists...
    NSError *err;
    fileLocation  = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp",vendorName]];

    fileWorkString = [[NSString alloc] initWithContentsOfFile:fileLocation encoding:NSUTF8StringEncoding error:&err];
    if (fileWorkString != nil)
        [self unpackFromString:fileWorkString];
    else{
        NSLog(@" ...no template found ");
    }
    [self dump];
}  //end loadTemplatesFromDisk


//=============(OCRTemplate)=====================================================
-(void) saveTemplatesToDisk : (NSString *)vendorName
{
    NSError *err;
    [self cleanupColumns];
    fileWorkString = [self packToString];
    fileLocation  = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp",vendorName]];

    [fileWorkString writeToFile:fileLocation atomically:YES encoding:NSUTF8StringEncoding error:&err];
    
     
    // writeToFile:fileLocation atomically:YES];
    NSLog(@" ...saved templates to %@ [%@]",fileLocation,fileWorkString);
}

//=============(OCRTemplate)=====================================================
// DHS 4/1 for loading a template from DB or from full table of PFObjects...
-(void) loadTemplateFromPFObject : (NSArray *) objects : (int) index
{
    if (index < 0 || index >= objects.count) return;
    [self->ocrBoxes removeAllObjects];
    PFObject *pfo = objects[index];
    NSString *ps = [pfo objectForKey:@"packedString"];
    [self unpackFromString:ps];
    ps = [pfo objectForKey:PInv_PDFFile_key];
    if (ps != nil) self->_pdfFile = ps;
} //end loadTemplateFromPFObject

//=============(OCRTemplate)=====================================================
// Use vendor name to find record, loads associated template...
-(void) readFromParse : (NSString *)vendorName
{
    if (vendorName == nil) return;
    PFQuery *query = [PFQuery queryWithClassName:@"templates"];
    if (![vendorName isEqualToString:@"*"]) //DHS 5/1 add wildcard support
        [query whereKey:@"vendor" equalTo:vendorName];
    [query orderByDescending:@"createdAt"]; //Get latest saved template (there may be many edits)...
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            if (objects.count > 0)
            {
                [self loadTemplateFromPFObject : objects : 0]; //4/1
                [self.delegate didReadTemplate : objects];
            }
            else
                [self.delegate errorReadingTemplate : @"Empty table"];
        }
        else
        {
            NSLog(@" no template / error");
            [self.delegate errorReadingTemplate : @"Read Error"];
        }
    }];
} //end readFromParse

//=============(OCRTemplate)=====================================================
-(void) readFromParseAsStrings
{
    PFQuery *query = [PFQuery queryWithClassName:@"templates"];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) { //Query came back...
            [self->recordStrings removeAllObjects];
            for( PFObject *pfo in objects) //Should only be one?
            {
                NSString *v  = [pfo objectForKey:@"vendor"];
                NSString *ps = [pfo objectForKey:@"packedString"];
                NSString *s = [NSString stringWithFormat:@"Vendor:%@:%@",v,ps];
                [self->recordStrings addObject:s];
            }
            [self.delegate didReadTemplateTableAsStrings : self->recordStrings];
        }
    }];

}


// Saves a new record...
//=============(OCRTemplate)=====================================================
-(void) saveToParse : (NSString *)vendorName
{
    //NSLog(@" unique User: savetoParse %@ %@ %@ %@",ampUserID,userID,userName,fbID);
    PFObject *templateRecord = [PFObject objectWithClassName:@"templates"];
    [self cleanupColumns];
    templateRecord[@"vendor"]        = vendorName;
    templateRecord[@"packedString"]  = [self packToString];
    if (_pdfFile != nil) templateRecord[PInv_PDFFile_key] = _pdfFile;
    templateRecord[PInv_VersionNumber] = _versionNumber;
    [templateRecord saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            NSLog(@" ...OCRTemplate [vendor:%@]->parse",vendorName);
            [self.delegate didSaveTemplate];
        } else {
            NSLog(@" ERROR: saving temlate to parse!");
        }
    }];
} //end saveToParse

//=============(OCRTemplate)=====================================================
-(void) setOriginalRects : (CGRect) tlr : (CGRect) trr
{
    tlDocRect = tlr;
    trDocRect = trr;
}


//=============(OCRTemplate)=====================================================
-(void) setTemplateOrientation : (int)w : (int) h
{
    if (w > h) //Landscape?
        orientationWhenReadable = @"landscape";
    else
        orientationWhenReadable = @"portrait";
    NSLog(@" set orient %@",orientationWhenReadable);
}

//=============(OCRTemplate)=====================================================
-(CGRect) getTLOriginalRect
{
    return tlDocRect;
}

//=============(OCRTemplate)=====================================================
-(CGRect) getTROriginalRect
{
    return trDocRect;
}



@end
