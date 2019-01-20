//
//    ___   ____ ____  ____                                        _
//   / _ \ / ___|  _ \|  _ \  ___   ___ _   _ _ __ ___   ___ _ __ | |_
//  | | | | |   | |_) | | | |/ _ \ / __| | | | '_ ` _ \ / _ \ '_ \| __|
//  | |_| | |___|  _ <| |_| | (_) | (__| |_| | | | | | |  __/ | | | |_
//   \___/ \____|_| \_\____/ \___/ \___|\__,_|_| |_| |_|\___|_| |_|\__|
//
//  OCRDocument.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//
// 1/10/19 in getColumnStrings, changed glyph fudge value!
//           may result in rows getting mixed up!

#import "OCRDocument.h"

@implementation OCRDocument


//=============(OCRDocument)=====================================================
-(instancetype) init
{
    if (self = [super init])
    {
        allPages             = [[NSMutableArray alloc] init];
        allWords             = [[NSMutableArray alloc] init];
        headerPairs          = [[NSMutableArray alloc] init];
        columnStringData     = [[NSMutableArray alloc] init];
        ignoreList           = [[NSMutableArray alloc] init];
        finalYs              = [[NSMutableArray alloc] init];

        gT10  = [[NSMutableSet alloc] init];
        gB10  = [[NSMutableSet alloc] init];
        gL10  = [[NSMutableSet alloc] init];
        gR10  = [[NSMutableSet alloc] init];
        gH20  = [[NSMutableSet alloc] init];
        gV20  = [[NSMutableSet alloc] init];
        gT50  = [[NSMutableSet alloc] init];
        gL50  = [[NSMutableSet alloc] init];
        useIgnoreList        = FALSE;
        srand((unsigned int)time(NULL));
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy"];
        NSString *ystr = [df stringFromDate:[NSDate date]];
        currentYear = ystr.intValue;
        
        unitScale = TRUE;
        hScale = vScale = 1.0;
    }
    return self;
}

//=============(OCRDocument)=====================================================
-(void) addColumnStringData : (NSMutableArray*)stringArray
{
    int clen = (int)stringArray.count; //Keep track of longest column...
    if (clen > _longestColumn) _longestColumn = clen;
    [columnStringData addObject:stringArray];
}

//=============(OCRDocument)=====================================================
-(void) clearGroups
{
    [gT10 removeAllObjects];
    [gB10 removeAllObjects];
    [gL10 removeAllObjects];
    [gR10 removeAllObjects];
    [gH20 removeAllObjects];
    [gV20 removeAllObjects];
    [gT50 removeAllObjects];
    [gL50 removeAllObjects];
}

//=============(OCRDocument)=====================================================
// Exhaustive pass over words,funnels them into various groups...
-(void) assembleGroups
{
    [self clearGroups];
    int index,dxmin,dymin,dxmax,dymax; //Make these properties?
    dxmin = dymin = 99999;
    dxmax = dymax = -99999;
    int xspread,yspread;
    int dx10,dy10,dx50,dy50,dx90,dy90;

    for (OCRWord *ow  in allWords)
    {
        int x = ow.left.intValue;
        int y = ow.top.intValue;
        if (x < dxmin) dxmin = x;
        if (y < dymin) dymin = y;
        if (x > dxmax) dxmax = x;
        if (y > dymax) dymax = y;
    }
    xspread = dxmax - dxmin;
    yspread = dymax - dymin;
    //Now get some stats...
    dx10 = dxmin + xspread/10;
    dy10 = dymin + yspread/10;
    dx50 = dxmin + xspread/2;
    dy50 = dymin + yspread/2;
    dx90 = dxmax - dx10;
    dy90 = dymax - dy10;
    index = 0;
    for (OCRWord *ow  in allWords)
    {
        NSNumber* inum = [NSNumber numberWithInt:index];
        NSNumber* xn = ow.left;
        NSNumber* yn = ow.top;
        int x = xn.intValue;
        int y = yn.intValue;
        if (x < dx10) [gL10 addObject:inum];  //Near L/R/T/B
        if (x > dx90) [gR10 addObject:inum];
        if (y < dy10) [gT10 addObject:inum];
        if (y > dy90) [gB10 addObject:inum];
        if (abs(x - dx50) < dx10) [gH20 addObject:inum]; //Near H center
        if (abs(y - dy50) < dy10) [gV20 addObject:inum]; //Near V Center
        if (x < dx50) [gL50 addObject:inum];  //Left half of page
        if (x < dy50) [gT50 addObject:inum];  //Top half
        index++;
    }
    //[self dumpGroup:gL50];
    //NSLog(@" duh done assssembling");
//    NSArray *dog = [self findTLWords];
    
} //end assembleGroups

//=============(OCRDocument)=====================================================
-(NSArray*) findTLWords
{
    NSMutableSet *set1 = [NSMutableSet setWithSet:gT10];
    [set1 intersectSet: gL10];
    return [set1 allObjects];
}

//=============(OCRDocument)=====================================================
-(NSArray*) findTRWords
{
    NSMutableSet *set1 = [NSMutableSet setWithSet:gT10];
    [set1 intersectSet: gR10];
    return [set1 allObjects];
}

//=============(OCRDocument)=====================================================
// Meant to find out which column contains ITEM, for instance...
-(int) findStringInHeaders : (NSString*)s
{
    int index = 0;
    NSString *lcs = s.lowercaseString;
    for (NSDictionary *d in headerPairs)
    {
        NSString* h = [d objectForKey:@"Field"];
        if ([h.lowercaseString isEqualToString:lcs]) return index;
        if ([h.lowercaseString containsString:lcs]) return index;
        index++;
    }
    return -1;
}

//=============(OCRDocument)=====================================================
-(void) dumpGroup : (NSMutableSet*)g
{
   for (NSNumber *n in g)
   {
       OCRWord *ow = allWords[n.longValue];
       NSLog(@" w[%d] %@",n.intValue,ow.wordtext);
   }
}

//=============(OCRDocument)=====================================================
-(void) dumpArray : (NSArray*)a
{
    for (NSNumber *n in a)
    {
        OCRWord *ow = allWords[n.longValue];
        NSLog(@" w[%d] %@",n.intValue,ow.wordtext);
    }
}

//=============(OCRDocument)=====================================================
-(void) dumpArrayFull : (NSArray*)a
{
    for (NSNumber *n in a)
    {
        OCRWord *ow = allWords[n.longValue];
        NSLog(@" w[%d] %@ [%@,%@ : %@,%@]",n.intValue,ow.wordtext,ow.top,ow.left,ow.width,ow.height);
    }
}

//=============(OCRDocument)=====================================================
-(void) dumpWordsInBox : (CGRect) rr
{
    NSMutableArray *a = [self findAllWordsInRect:rr];
    [self dumpArray:a];
}

//=============(OCRDocument)=====================================================
// Fix OCR errors in numeric strings...
//    $ assumed to mean 5 for instance...
//    assumed to be ONE NUMBER in the string!
-(NSString*) c : (NSString *)nstr
{
    NSString *outstr;
    outstr = [nstr   stringByReplacingOccurrencesOfString:@" " withString:@""]; //No spaces in number...
    outstr = [outstr stringByReplacingOccurrencesOfString:@"I" withString:@"1"]; // I -> 1
    outstr = [outstr stringByReplacingOccurrencesOfString:@"B" withString:@"8"]; // B -> 8
    outstr = [outstr stringByReplacingOccurrencesOfString:@"O" withString:@"0"]; // O -> 0
    outstr = [outstr stringByReplacingOccurrencesOfString:@"o" withString:@"0"]; // o -> 0
    outstr = [outstr stringByReplacingOccurrencesOfString:@"s" withString:@"5"]; // s -> 5
    outstr = [outstr stringByReplacingOccurrencesOfString:@"S" withString:@"5"]; // S -> 5
    return outstr;
}

//=============(OCRDocument)=====================================================
// Fix OCR errors in numeric strings...
//    $ assumed to mean 5 for instance...
//    assumed to be ONE NUMBER in the string!
-(NSString*) cleanUpNumberString : (NSString *)nstr
{
    NSString *outstr;
    outstr = [nstr   stringByReplacingOccurrencesOfString:@"O" withString:@"0"];
    outstr = [outstr stringByReplacingOccurrencesOfString:@"C" withString:@"0"];  //C ... really?
    outstr = [outstr stringByReplacingOccurrencesOfString:@"o" withString:@"0"];
    outstr = [outstr stringByReplacingOccurrencesOfString:@"S" withString:@"5"];
    outstr = [outstr stringByReplacingOccurrencesOfString:@"B" withString:@"8"];
    outstr = [outstr stringByReplacingOccurrencesOfString:@"'" withString:@" "]; //Bad punctuation?
    outstr = [outstr stringByReplacingOccurrencesOfString:@"`" withString:@" "];
    outstr = [outstr stringByReplacingOccurrencesOfString:@" " withString:@""]; //No spaces in number...
    return outstr;
}


//=============(OCRDocument)=====================================================
// Makes sure price has format DDD.CC
-(NSString *)cleanupPrice : (NSString *)s
{
    //NSLog(@" cleanup Price in [%@]",s);
    NSString* ptst = [s stringByReplacingOccurrencesOfString:@" " withString:@""];
    BOOL numeric = [self isStringAPrice:ptst];
    NSString *sout = @"";
    if (!numeric)  //No numerals found? Just set to zero
    {
        //sout = @"0.00";
        //NSLog(@" non-numeric?");
    }
   // else
    {
        sout = [s stringByReplacingOccurrencesOfString:@" " withString:@""]; //No spaces please
        sout = [self cleanUpNumberString:sout];                                 //Fix typos and pull blanks
        sout = [sout stringByReplacingOccurrencesOfString:@"," withString:@""]; //No commas please
        //Dissemble to dollars and cents, then reassemble to guarantee 2 digits of cents
        float fdollarsAndCents = [sout floatValue];
        int d = (int) fdollarsAndCents;
        int c = floor((100.0 * fdollarsAndCents) + 0.5) - 100*d;
        sout = [NSString stringWithFormat:@"%d.%2.2d",d,c];

    }
    //NSLog(@" .....out  [%@]",sout);

    return sout;
}

//=============(OCRDocument)=====================================================
// Fix typos etc in price / amount columns..
-(NSMutableArray *) cleanUpPriceColumns : (int) index : (NSMutableArray*) a
{
    //THIS NEEDS IMPROVEMENT, and abstraction!
    if (index != _priceColumn &&
        index != _amountColumn &&
        index != _quantityColumn) return a; //Using our 5 canned columns
    //Need a cleanup?
    NSMutableArray *aout = [[NSMutableArray alloc] init];
    if ( index != _quantityColumn) //Cleanup dollar amounts...
    {
        for (NSString * s in a) [aout addObject:[self cleanupPrice:s]];
    }
    else //quantity
    {
        //NSLog(@" cleanup quantity...");
        for (NSString * s in a) [aout addObject:[self cleanUpNumberString : s]];
    }
    return aout;
}


//=============(OCRDocument)=====================================================
// Fix OCR errors in name strings...
-(NSString*) cleanUpProductNameString : (NSString *)pstr
{
    NSString *outstr;
    outstr = [pstr stringByReplacingOccurrencesOfString:@"|" withString:@""]; //No vertical bars
    outstr = [outstr stringByReplacingOccurrencesOfString:@"_" withString:@""]; //No underbars!
    return outstr;
}


//=============(OCRDocument)=====================================================
-(void) clear
{
    [allPages removeAllObjects];
    [allWords removeAllObjects];
    //Clear postOCR stuff too...
    for (int i=0;i<MAX_QPA_ROWS;i++)
    {
        postOCRQuantities[i]  = @"";
        postOCRPrices[i]      = @"";
        postOCRAmounts[i]     = @"";
        postOCRMinorErrors[i] = 0;
    }
}


//=============(OCRDocument)=====================================================
-(void) clearAllColumnStringData
{
    [columnStringData removeAllObjects];
    //By default template columns should be laid out in this manner.
    //The code tries to figure out which is which by matching header strings,
    //  but it doesn't always work! This needs to be improved!
    _longestColumn = 0;
    _itemColumn = 0;
    _quantityColumn = 1;
    _descriptionColumn = 2;
    _priceColumn = 3;
    _amountColumn = 4;
}

//=============(OCRDocument)=====================================================
// Date formatter returns nil date on bogus input...
-(NSDate *) isItADate : (NSString *)tstr
{
    NSString *dformat1 = @"yyyy-MM-dd";
    NSString *dformat2 = @"MM-dd-yy";
    NSString *dformat3 = @"MM/dd/yy";
    NSString *dformat4 = @"dd-MMM-yy";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //OK try some different formats...
    [dateFormatter setDateFormat:dformat1];
    NSDate *dtest = [dateFormatter dateFromString:tstr];
    if (dtest != nil) return dtest;
    [dateFormatter setDateFormat:dformat2];
    dtest = [dateFormatter dateFromString:tstr];
    if (dtest != nil) return dtest;
    [dateFormatter setDateFormat:dformat3];
    dtest = [dateFormatter dateFromString:tstr];
    if (dtest != nil) return dtest;
    [dateFormatter setDateFormat:dformat4];
    dtest = [dateFormatter dateFromString:tstr];
    if (dtest != nil) return dtest;
    return nil;
    
} //end isItADate

//=============OCRDocument=====================================================
// Assumes r is in document coords, exhaustive search.
//  are words' origin at top left or bottom left?
-(NSMutableArray *) findAllWordStringsInRect : (CGRect )rr
{
    NSMutableArray *a = [self findAllWordsInRect:rr];
    if (a == nil) return nil;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    //Process, get words...
    for (NSNumber *n in a)
    {
        OCRWord *ow  = [allWords objectAtIndex:n.longValue];
        [result addObject:ow.wordtext];
    }
    return result;
} //end findAllWordStringsInRect

//=============OCRDocument=====================================================
// Assumes r is in document coords, exhaustive search.
//  are words' origin at top left or bottom left?
-(NSMutableArray *) findAllWordsInRect : (CGRect )rrIn
{
    
    int xi,yi,x2,y2,index;
    //First: Convert from template to document space
    //  document may be smaller than the one used to
    //  create the template!!
    CGRect rr = [self  template2DocRect : rrIn];
    
    xi = (int)rr.origin.x;  //Get bounding box limits...
    yi = (int)rr.origin.y;
    x2 = xi + (int)rr.size.width;
    y2 = yi + (int)rr.size.height;
    NSMutableArray *aout = [[NSMutableArray alloc] init]; //Results go here
    index = 0;
    for (OCRWord *ow  in allWords)
    {
        int x = (int)ow.left.intValue; //Get top left corner?
        int y = (int)ow.top.intValue;
// STOOPID DEBUG
//        if ([ow.wordtext isEqualToString:@"1,77"])
//        {
//            NSLog(@" bing 177"); //asdf
//        }
        if (x >= xi && x <= x2 && y >= yi && y <= y2) //Hit!
        {
            NSNumber *n = [NSNumber numberWithInt:index];
            // There is a list of words to ignore in ignore boxes...
            if (!useIgnoreList || ([ignoreList indexOfObject:n] == NSNotFound))
            {
                [aout addObject:n]; // OK? add to result
            }
        }
        index++;
    } //end for ow
    return aout;
} //end findAllWordsInRect


//=============(OCRDocument)=====================================================
-(void) addIgnoreBoxItems  : (CGRect )rr
{
    useIgnoreList = FALSE;
  //  rr.origin.x +=_docRect.origin.x;
  //  rr.origin.y +=_docRect.origin.y;
    NSMutableArray *ir = [self findAllWordsInRect:rr];
    [ignoreList addObjectsFromArray:ir];
    useIgnoreList = TRUE;
} //end addIgnoreBoxItems

//=============(OCRDocument)=====================================================
// Look at some random words, get average height thereof
-(void) getAverageGlyphHeight
{
    int maxlim = (int)allWords.count - 1;
    int count = 8;
    int sum = 0;
    for (int i=0;i<count;i++) //let's hope we have 8 words here!
    {
        int testIndex = (int)(drand(1.0,(double)maxlim));
        OCRWord *ow = [allWords objectAtIndex:testIndex];
        sum += ow.height.intValue;
    }
    _glyphHeight = sum / count;
} //end getAverageGlyphHeight


//=============(OCRDocument)=====================================================
// Uses rr to get column L/R boundary, uses rowY's to get top area to look at...
-(NSArray*)  getHeaderNames
{
    NSMutableArray *hn = [[NSMutableArray alloc] init];
    for (NSDictionary *d in headerPairs)
    {
        NSString* h = [d objectForKey:@"Field"];
        [hn addObject:h];
    }
    return hn;
} //end getHeaderNames

//=============(OCRDocument)=====================================================
// Gets sorted array of words as they should appear in a sentence, given
//  an array of separate words assumed to be in a retangle. Produces a hash
//  for each word that guarantees proper sentence placement, forces words
//  into line. Note ytolerance...
-(NSMutableArray *) getSortedWordPairsFromArray : (NSMutableArray*) a
{
    NSMutableArray *wordPairs = [[NSMutableArray alloc] init];
    //NSLog(@" assemble word...");
    int ys[32];  //we can handle up to 32 words...
    for (int i=0;i<32;i++) ys[i] = -999;
    int yptr = 0;
    int ytolerance = 1.5 * _glyphHeight;
    int fonyWidth = topmostRightRect.origin.x + topmostRightRect.size.width;
    for (NSNumber *n in a)
    {
        OCRWord *ow = [allWords objectAtIndex:n.longValue];
        int y = ow.top.intValue;
        int w = ow.width.intValue;
        //Keep a collection of row y values, if we are near an earlier word's y, just use it!
        //  this fixes the problem of slightly staggered words along a line...
        for (int i=0;i<yptr;i++) if (abs(y-ys[i]) < ytolerance) y = ys[i];
        ys[yptr++] = y;
        int abspos = fonyWidth * y + ow.left.intValue; //Abs pixel position in document
        //NSLog(@"add2wordpairs wid %d y %d owleft %d w %@ abspos %d",fonyWidth,y,ow.left.intValue,ow.wordtext,abspos);
        //add dict of string / y pairs
        [wordPairs addObject:@{@"Word": ow.wordtext,@"XY":[NSNumber numberWithInt:abspos],@"W":[NSNumber numberWithInt:w],@"T":[NSNumber numberWithInt:y]}];
    }
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"XY" ascending:YES];
    [wordPairs sortUsingDescriptors:@[descriptor]];
    return wordPairs;
} //end getSortedWordPairsFromArray

//=============(OCRDocument)=====================================================
// Finds header in doc, given r as possible place to start. returns top left ypos
//  1/16 Add some smarts using column boundaries (assumed already set) to
//  get some clean header strings...
-(int) findHeader : (CGRect)r : (int) expandYBy
{
    CGRect bigr = CGRectMake(r.origin.x, r.origin.y-expandYBy,
                             r.size.width, r.size.height+2*expandYBy);
    NSMutableArray *a = [self findAllWordsInRect:bigr];
   // [self dumpArrayFull:a];
    BOOL found = FALSE;
    int yTest = bigr.origin.y;
    //NOTE: this will fail if there is an occurrance of Description ABOVE the header!
    int index = 0;
    for (NSNumber *n in a) //Look for obvious keyword now
    {
        OCRWord *ow = allWords[n.longValue];
        if ([ow.wordtext.lowercaseString isEqualToString:@"description"])
            {
                found = TRUE;
                yTest  = ow.top.intValue;  //Document space!
                int xt = ow.left.intValue;
                NSLog(@" description found:index %d xy (%d,%d)",index,yTest,xt);
                break;
            }
          index++;
    }
    if (!found)
    {
        NSLog(@" Error: no header found!");
        return -1; //Failure code
    }
    NSMutableArray *b = [[NSMutableArray alloc] init];
    for (NSNumber *n in a) //Get every word on the same lines as the keyword
    {
        OCRWord *ow = allWords[n.longValue];
        if (abs(ow.top.intValue - yTest) < 1*_glyphHeight ) [b addObject: n];
    }
   // [self dumpArrayFull:b];
    NSString * hdrSentence =  [self assembleWordFromArray : b : FALSE : 2];
    //NSLog(@" found header %@",hdrSentence);
    //Check for other keywords...
    found = FALSE;
    if ([hdrSentence.lowercaseString containsString:@"price"]) found = TRUE;
    if ([hdrSentence.lowercaseString containsString:@"item"]) found = TRUE;
    if ([hdrSentence.lowercaseString containsString:@"amount"]) found = TRUE;
    _headerYpos = yTest;
    if (found) return yTest;
    return -1;
} //end findHeader

//=============(OCRDocument)=====================================================
// Array of words is coming in from a box, take all words and make a sentence...
//  Numeric means don't padd with spaces...
-(NSString *) assembleWordFromArray : (NSMutableArray *) a : (BOOL) numeric : (int) maxLines
{
    if (a.count == 0) return @""; //handle edge cases
    NSMutableArray *wordPairs = [self getSortedWordPairsFromArray:a];
    //All sorted! Now pluck'em out!
    NSString *s = @"";
    int i    = 0;
    NSNumber* topy = [NSNumber numberWithInt:0];
    for (NSDictionary *d in wordPairs)
    {
        NSNumber* nexty  = [d objectForKey:@"T"];
        //NSLog(@" ny %d ty %d",nexty.intValue,topy.intValue);
        if (i == 0) topy = nexty;
        if (nexty.intValue - topy.intValue > maxLines*_glyphHeight)
        {
            //NSLog(@" too many rows?");
        }
        else //Next word not too far down? append
        {
            s = [s stringByAppendingString:[d objectForKey:@"Word"]];
            if (!numeric) s = [s stringByAppendingString:@" "];
        }
        i++;
    }
    //NSLog(@" ...assembled result [%@]",s);
    return s;
} //end assembleWordFromArray



//=============(OCRDocument)=====================================================
// Uses rr to get column L/R boundary, uses rowY's to get top area to look at...
// 1/18 uses finalYs, gotten from computeRowYpositions
-(NSMutableArray*)  getColumnStrings: (CGRect)rr : (int) column
{
    //NOTE the rowYs array is coming in in DOCUMENT coords!!!
    NSMutableArray *resultStrings = [[NSMutableArray alloc] init];
    int yc = (int)finalYs.count;
    for (int i=0;i<yc;i++)
    {
        NSNumber *ny = finalYs[i];
        //DHS Jan 10 1/10/19 This may be needed for docs that are tilted by a few degrees..
        // What would be best would be something that follows the page's tilt.....
        int thisY = ny.intValue - _glyphHeight; //1/9/19 Fudge by half glyph height
//        int thisY = ny.intValue - _glyphHeight/2; //Fudge by half glyph height
        thisY = [self doc2templateY:thisY];      //Go back to template coords...
        int nextY = rr.origin.y + rr.size.height;
        if (i < yc-1)
        {
            NSNumber *nyy = finalYs[i+1];
            nextY = nyy.intValue - 1;
        }
        nextY = [self doc2templateY:nextY];
        CGRect cr = CGRectMake(rr.origin.x, thisY, rr.size.width, nextY-thisY);
        NSMutableArray *a = [self findAllWordsInRect:cr];
        //NSLog(@" getColumnString:(col %d row %d) rect %@",column,i,NSStringFromCGRect(cr));
        //[self dumpArray:a];
        [resultStrings addObject:[self assembleWordFromArray : a : FALSE : 2]];
    }
    
    NSString *headerForThisColumn = [self getHeaderStringFromRect:rr];
    headerForThisColumn = headerForThisColumn.lowercaseString;
    //let's see what it contains:
    if ([headerForThisColumn containsString:@"item"])        _itemColumn = column;
    if ([headerForThisColumn containsString:@"quantity"])    _quantityColumn = column;
    if ([headerForThisColumn containsString:@"description"]) _descriptionColumn = column;
    if ([headerForThisColumn containsString:@"price"])       _priceColumn = column;
    if ([headerForThisColumn containsString:@"amount"])      _amountColumn = column;
    NSLog(@" column header[%d] %@ ic %d qc %d",column,headerForThisColumn,_itemColumn,_quantityColumn);

    return resultStrings;
} //end getColumnStrings

//=============(OCRDocument)=====================================================
// Incoming rect is a template rect!!! (passed in by parent)
-(NSString*) getHeaderStringFromRect : (CGRect)rr
{
    NSString *cname = @"";
    CGRect dr = [self template2DocRect:rr];
    for (NSDictionary*d in headerPairs) //Look at our headers,
    {
        NSNumber *nx = [d objectForKey:@"X"]; // find one with an X near our rect
        if (nx.intValue >= dr.origin.x  && nx.intValue <= dr.origin.x + rr.size.width)
            return [d objectForKey:@"Field"];
    }
    return cname;
}


//=============(OCRDocument)=====================================================
-(NSMutableArray *) getColumnYPositionsInRect : (CGRect )rr : (BOOL) numeric
{
    //Get all content within this rect, assume one item per line!
    NSMutableArray *a = [self findAllWordsInRect:rr];
    NSLog(@" getColumnYPositionsInRect %d,%d : %d,%d",(int)rr.origin.x,(int)rr.origin.y,(int)rr.size.width,(int)rr.size.height);
    [self dumpArrayFull:a];
    NSMutableArray *colPairs = [[NSMutableArray alloc] init];
    int oldy = -99999;
    //Get each item in our column box...
    for (NSNumber* n  in a)
    {
        OCRWord *ow = [allWords objectAtIndex:n.longValue];
        int ty = ow.top.intValue;
        if (abs(ty - oldy) > _glyphHeight) //Check Y for new row? (rows may be out of order)
        {
            oldy = ty;
            NSString *s = ow.wordtext;
            [colPairs addObject:@{@"Field": s,@"Y":ow.top}]; //add dict of string / y pairs
        }
    }
    //Perform sort of dictionary based on the Y coordinate ...
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"Y" ascending:YES];
    [colPairs sortUsingDescriptors:@[descriptor]];
    NSMutableArray *yP = [[NSMutableArray alloc] init];
    for (NSDictionary *d in colPairs) [yP addObject:[d objectForKey:@"Y"]];
    return yP;
    
} //end getColumnYPositionsInRect


//=============(OCRDocument)=====================================================
// complex. uses two RH price/amount columns, interleaves their different rows
//   together, sorts and cleans out redundancies.  produces finalYs array..
-(int) computeRowYpositions : (int) numCols : (CGRect)rp : (CGRect)ra
{
    [finalYs removeAllObjects];
    if (numCols < 4)  //We need at least Quantity : Description : Price : Amount
    {
        return -1; //ERROR
    }
    
    int columnDataTop = [self doc2templateY:_headerYpos] + 1.5*_glyphHeight;
    
    //Get Y position of data in both price and amount columns...
    rp.origin.y = columnDataTop; //Start just below found headerY
    //NOTE: rowYs and rowY2s are already in DOCUMENT coords!
    NSMutableArray* rowYs = [self getColumnYPositionsInRect:rp : TRUE];
    ra.origin.y = columnDataTop; //Start just below found headerY
    NSMutableArray* rowY2s = [self getColumnYPositionsInRect:ra : TRUE];
    //Merge these two together, toss dupes (redudancy in case of missing or smudged column data)
    NSMutableArray *allys = [NSMutableArray arrayWithArray:rowYs];
    [allys addObjectsFromArray:rowY2s]; //concatenate arrays...
    NSArray *sortedArray = [allys sortedArrayUsingSelector: @selector(compare:)];
    NSNumber *lastY = [NSNumber numberWithDouble:-9999.0];
    for (NSNumber *nextY in sortedArray)
    {
        int dy = nextY.doubleValue - lastY.doubleValue;
        if (dy >_glyphHeight) [finalYs addObject:nextY];
        lastY = nextY;
    }
    return 0; //OK
} //end getRowYpositions'


//=============(OCRDocument)=====================================================
// Assumes 2D column array fully populated....
-(NSMutableArray *) getRowFromColumnStringData : (int)index
{
    int nc = (int)columnStringData.count; //Number of columns
    NSMutableArray *a = [[NSMutableArray alloc] init];
    for (int i=0;i<nc;i++)
    {
        NSArray*ac     = [columnStringData objectAtIndex:i]; //Column of strings...
        NSString *item = [ac objectAtIndex:index]; //Get row... (may be blank string)
        [a addObject:item];
    }
    return a;
} //end getRowFromColumnStringData

//=============(OCRDocument)=====================================================
// Gets absolute limit for all text found on document, stores in CGRect
-(CGRect) getDocRect
{
    int minx,miny,maxx,maxy;
    minx = miny = 99999;
    maxx = maxy = -99999;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue;
        int y1 = (int)ow.top.intValue;
        int x2 = x1 + (int)ow.width.intValue;
        int y2 = y1 + (int)ow.height.intValue;
        if (x1 < minx) minx = x1;
        if (y1 < miny) miny = y1;
        if (x2 > maxx) maxx = x2;
        if (y2 > maxy) maxy = y2;
    } //end for loop
    _docRect = CGRectMake(minx, miny, maxx-minx, maxy-miny);
    //NSLog(@" doc lims (%d,%d) to (%d,%d)",minx, miny, maxx , maxy );
    return _docRect;
} //end getDocRect

//=============(OCRDocument)=====================================================
-(CGRect) getWordRectByIndex : (int) index
{
    if (index < 0 || index >= allWords.count) return CGRectMake(0,0, 0, 0);
    OCRWord *ow = [allWords objectAtIndex:index];
    return CGRectMake(ow.left.intValue,  ow.top.intValue,
                      ow.width.intValue, ow.height.intValue);
}

//=============(OCRDocument)=====================================================
-(CGRect) getBLRect
{
    int minx,maxy,index,foundit;
    minx = 99999;
    maxy = -99999;
    index   = 0;
    foundit = -1;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue;
        int y1 = (int)ow.top.intValue + (int)ow.height.intValue;
        if (x1 < minx && y1 > maxy) {
            minx = x1;
            maxy = y1;
            foundit = index;
        }
        index++;
    }
    return  [self getWordRectByIndex:foundit];
} //end getBLRect

//=============(OCRDocument)=====================================================
-(CGRect) getBRRect
{
    int maxx,maxy,index,foundit;
    maxx = -99999;
    maxy = -99999;
    index   = 0;
    foundit = -1;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue + (int)ow.width.intValue;
        int y1 = (int)ow.top.intValue  + (int)ow.height.intValue;
        if (x1 > maxx && y1 > maxy) {
            maxx = x1;
            maxy = y1;
            foundit = index;
        }
        index++;
    }
    return  [self getWordRectByIndex:foundit];
} //end getBRRect

//=============(OCRDocument)=====================================================
-(void) fixBogusWHIfNeeded
{
    if (_height == 0)
    {
        NSLog(@" ERROR: zero doc height: stubbing in 1500");
        _height = 1500;
    }
    if (_width == 0)
    {
        NSLog(@" ERROR: zero doc width: stubbing in 1000");
        _width = 1000;
    }

}

//=============(OCRDocument)=====================================================
// Rightmost item in top 10%
-(CGRect) getRightmostTopRect
{
    [self fixBogusWHIfNeeded];
    int cuty = _height/4;  //Doesn't look like this matches the templates TRR scan limit!
    int maxx = -99999;
    int foundit = -1;
    int index = 0;
    for (OCRWord *ow  in allWords)
    {
        //DHS 1/16 added the width this wasn't matching template's maxx???
        int x1 = (int)(ow.left.intValue + ow.width.intValue);
        int y1 = (int)ow.top.intValue;
        if (y1 < cuty)
        {
            if (x1 > maxx)
            {
                maxx = x1;
                foundit = index;
            }
        }
        index++;
    }
    return  [self getWordRectByIndex:foundit];
}

//=============(OCRDocument)=====================================================
// Leftmost item in top 10%
-(CGRect) getLeftmostTopRect
{
    [self fixBogusWHIfNeeded];
    int cuty = _height/4;
    int minx = 99999;
    int foundit = -1;
    int index = 0;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue;
        int y1 = (int)ow.top.intValue;
        if (y1 < cuty)
        {
            if (x1 < minx)
            {
                minx = x1;
                foundit = index;
            }
        }
        index++;
    }
    return  [self getWordRectByIndex:foundit];

}

//=============(OCRDocument)=====================================================
-(CGRect) getTLRect
{
    [self fixBogusWHIfNeeded];
    int minx,miny,index,foundit;
    minx = miny = 99999;
    index   = 0;
    foundit = -1;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue;
        int y1 = (int)ow.top.intValue;
        if (y1 < _height/4)
        {
            // Look for farthest left near the top
            //OUCH! We don't have image height for incoming PDF data!?!?!
            if (x1 < minx && y1 < miny) {
                minx = x1;
                miny = y1;
                foundit = index;
            }
        }
       index++;
    }
    return  [self getWordRectByIndex:foundit];
} //end getTLRect

//=============(OCRDocument)=====================================================
-(CGRect) getTRRect
{
    [self fixBogusWHIfNeeded];
   int maxx,miny,index,foundit;
    maxx = -99999;
    miny = 99999;
    index   = 0;
    foundit = -1;
    for (OCRWord *ow  in allWords)
    {
        int x1 = (int)ow.left.intValue + (int)ow.width.intValue;
        int y1 = (int)ow.top.intValue;
        if (y1 < _height/4)
        {
            //NSLog(@" word [%@] xy %d %d",ow.wordtext,x1,y1);
            //Look for farthest right near the top!
            //OUCH! We don't have image height for incoming PDF data!?!?!
            if (x1 > maxx && y1 < 99999)
            {
                //NSLog(@" bing: Top Right");
                maxx = x1;
                miny = y1;
                foundit = index;
            }
        }
        index++;
    }
    return  [self getWordRectByIndex:foundit];
} //end getTRRect

//=============(OCRDocument)=====================================================
-(BOOL) isStringAnInteger : (NSString *)s
{
    NSCharacterSet *alphaNums = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:s];
    return [alphaNums isSupersetOfSet:inStringSet];
} //end isStringAnInteger

//=============(OCRDocument)=====================================================
-(BOOL) isStringAnLog : (NSString *)s
{
    NSCharacterSet *alphaNums = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:s];
    return [alphaNums isSupersetOfSet:inStringSet];
} //end isStringAnInteger

//=============(OCRDocument)=====================================================
-(BOOL) isStringAPrice : (NSString *)s
{
    NSCharacterSet *alphaNums = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:s];
    return [alphaNums isSupersetOfSet:inStringSet];
} //end isStringAnInteger

//=============(OCRDocument)=====================================================
-(NSString*)getNthWord : (NSNumber*)n
{
    OCRWord *ow = [allWords objectAtIndex:n.longValue];
    return ow.wordtext;
}

//=============(OCRDocument)=====================================================
-(NSNumber*)getNthXCoord : (NSNumber*)n
{
    OCRWord *ow = [allWords objectAtIndex:n.longValue];
    return ow.left;
}

//=============(OCRDocument)=====================================================
-(NSNumber*)getNthXWidth : (NSNumber*)n
{
    OCRWord *ow = [allWords objectAtIndex:n.longValue];
    return ow.width;
}

//=============(OCRDocument)=====================================================
-(NSNumber*)getNthYCoord : (NSNumber*)n
{
    OCRWord *ow = [allWords objectAtIndex:n.longValue];
    return ow.top;
}

//=============(OCRDocument)=====================================================
-(NSString*)getStringStartingAtXY : (NSNumber*)n : (NSNumber*)minx : (NSNumber*)miny
{
    int lastx   = minx.intValue;
    int acrossx = lastx;
    NSString *s = @"";
    int index   = n.intValue;
    int wcount  = 0;
    BOOL done   = FALSE;
    while (!done) //spread of 40 = too much space between words, end of phrase?
    {
        OCRWord *ow = [allWords objectAtIndex:index];
        acrossx = ow.left.intValue;
        if ((acrossx - lastx < 40) &&  (acrossx >= lastx) && wcount < 8) //max 8 words increasing across X...
        {
            s = [s stringByAppendingString:[NSString stringWithFormat:@" %@",ow.wordtext]];
            lastx+= ow.width.intValue;
            index++;
            wcount++;
        }
        else done=TRUE;
    }
    return s;
} //end getStringStartingAtXY


//=============(OCRDocument)=====================================================
-(NSDate *)getGarbledDate : (NSString *) dstr
{
    if (dstr.length < 8) return nil; //Too short!
    NSString*dclean = [self cleanUpNumberString : dstr]; //Get rid of weird typos...
    //Try to fix garbled date, where slashes are replaced by ones for instance...
    NSString *tmonth = [dclean substringToIndex:2];
    int imon,iday,iyear;
    iyear = currentYear;
    iday  = 1;
    imon = tmonth.intValue;
    if (imon >= 1 && imon <= 12) //Got a month?
    {
        int slen = (int)dclean.length;
        NSString *tday = [dclean substringWithRange:NSMakeRange(3, 2)];
        iday = tday.intValue;
        NSString *tyear = @"";
        if (slen > 8)
        {
            tyear = [dclean substringWithRange:NSMakeRange(6, slen-6)];
            iyear = tyear.intValue;
            //Try to make sense of year:
            if (iyear < 100) iyear += 2000;
            else if (iyear < 1900) iyear = currentYear;
        }
        
        NSString *datestr = [NSString stringWithFormat:@"%4.4d-%2.2d-%2.2d",iyear,imon,iday];
        NSDateFormatter *dformat = [[NSDateFormatter alloc]init];
        [dformat setDateFormat:@"yyyy-MM-dd"];
        return [dformat dateFromString:datestr];
    } //end imon
    return nil;
} //end getGarbledDate

//=============(OCRDocument)=====================================================
// Given array of field numbers, looks for date-like strings...
-(NSDate *) findDateInArrayOfFields : (NSArray*)aof
{    
    for (NSNumber* n in aof)
    {
        NSString *testText = [self getNthWord:n];
        if ([testText containsString:@"/"]) //Is this good enough?
        {
            return [self parseDateFromString:testText];
        }
        NSDate *dgarbled = [self getGarbledDate:testText];
        if (dgarbled != nil) return dgarbled;
    }
    return nil;
} //end findDateInArrayOfFields


//=============(OCRDocument)=====================================================
// Given array of field numbers, finds first string which is a legit integer...
-(int) findIntInArrayOfFields : (NSArray*)aof
{
    int foundInt = 0;
    for (NSNumber* n in aof)
    {
        NSString *testText = [self getNthWord:n];
        testText = [testText stringByReplacingOccurrencesOfString:@"\"" withString:@""]; //No quotes please
        if ([self isStringAnInteger:testText] )
            foundInt = [testText intValue];
    }
    return foundInt;
} //end findIntInArrayOfFields

//=============(OCRDocument)=====================================================
-(long) findLongInArrayOfFields : (NSArray*)aof
{
    long foundLong = 0;
    for (NSNumber* n in aof)
    {
        NSString *testText = [self getNthWord:n];
        testText = [testText stringByReplacingOccurrencesOfString:@"B" withString:@"8"]; //B? maybe 8!
        testText = [testText stringByReplacingOccurrencesOfString:@"I" withString:@"1"]; //I? maybe 1!
        testText = [testText stringByReplacingOccurrencesOfString:@"\"" withString:@""]; //No quotes please
        if ([self isStringAnInteger:testText] ) foundLong = (long)[testText longLongValue];
    } //end for n
    return foundLong;
} //end findLongInArrayOfFields

//=============(OCRDocument)=====================================================
// Given array of field numbers, finds first string which is a legit integer...
-(float) findPriceInArrayOfFields : (NSArray*)aof
{
    float foundFloat = 0.0f;
    for (NSNumber* n in aof)
    {
        NSString *testText = [self getNthWord:n];
        testText = [testText stringByReplacingOccurrencesOfString:@"$" withString:@""]; //No dollars please
        testText = [testText stringByReplacingOccurrencesOfString:@"\"" withString:@""]; //No quotes please
        if ([self isStringAPrice:testText] )
            foundFloat = testText.floatValue;
    }
    return foundFloat;
} //end findIntInArrayOfFields


//=============(OCRDocument)=====================================================
-(NSString *) findTopStringInArrayOfFields : (NSArray*)aof
{
    //First make sure we get top field...
    NSNumber* topn;
    int minx = 999999;
    int miny = 999999;
    for (NSNumber* n in aof)
    {
        int xoff = [self getNthXCoord:n].intValue; // Get word's XY coord
        int yoff = [self getNthYCoord:n].intValue;
        if (yoff < miny && xoff < minx) //Is it top left item?
        {
            minx = xoff; //Store xy position and index
            miny = yoff;
            topn = n;
        }
    } //end for n
    return [self getStringStartingAtXY : topn :
            [NSNumber numberWithInt:minx] : [NSNumber numberWithInt:miny]];
} //end findTopStringInArrayOfFields


//=============(OCRDocument)=====================================================
// From stackoverflow...
-(NSDate*) parseDateFromString : (NSString*) s
{
    NSError *error = NULL;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:(NSTextCheckingTypes)NSTextCheckingTypeDate error:&error];
    
    NSArray *matches = [detector matchesInString:s
                                         options:0
                                           range:NSMakeRange(0, [s length])];
    
    for (NSTextCheckingResult *match in matches) {
        if ([match resultType] == NSTextCheckingTypeDate) {
            NSDate *date = [match date];
            return date;
        }}
    return nil;
} //end parseDateFromString


//=============(OCRDocument)=====================================================
// Sets up internal header column names based on passed array of words forming header
//   called by OCRTopObject
-(void) parseHeaderColumns : (NSMutableArray*)colRectz : (CGRect) hr
{
    if (colRectz == nil || colRectz.count == 0)
    {
        NSLog(@" ERROR: parseHeaderColumns missing column boxes");
        return;
    }
    NSLog(@" parseHeaderColumns: dump of bigrect:");
    //[self dumpArrayFull:[self findAllWordsInRect:hr]];
    //Let's get some header rects first, using colRectz...
    //NSMutableArray *cr = [[NSMutableArray alloc] init];
    int i = 0;
    for (NSValue *rectObj in colRectz)
    {
        CGRect rcFrame = [rectObj CGRectValue];
        //Intersect w/ header frame
        rcFrame.origin.y = hr.origin.y;
        rcFrame.size.height = hr.size.height;
        //Try expanding header field a bit...
        rcFrame.origin.y -=_glyphHeight;
        rcFrame.size.height +=2*_glyphHeight;
        //NSLog(@" annnd headerRect for column %d is %@",i,NSStringFromCGRect(rcFrame));
        NSMutableArray *a = [self findAllWordsInRect:rcFrame];
        [self dumpArrayFull:a];
        i++;
    }
    
    
    NSMutableArray *aof = [[NSMutableArray alloc] init]; //STUB for below
    [self fixBogusWHIfNeeded];
    BOOL firstField = TRUE;
    int acrossX,lastX;
    NSString *hstr = @"";
    acrossX = lastX = 0;
    [headerPairs removeAllObjects];
    NSMutableArray *wordPairs = [self getSortedWordPairsFromArray:aof];
    lastX = -1;
    int firstX = -1;
    //DHS 12/31: The PDF _width is BOGUS, too small to account for document spread.
    //   use this fony width instead to create the XY hash...
    int fonyWidth = topmostRightRect.origin.x + topmostRightRect.size.width;

    for (NSMutableDictionary *d in wordPairs)
    {
        NSNumber *n    = [d objectForKey:@"XY"];
        NSNumber *nw   = [d objectForKey:@"W"];
        NSString *wstr = [d objectForKey:@"Word"];
        int x = n.intValue;
        int xc = x / fonyWidth;
        int xoff = x - (fonyWidth*xc);
        //NSLog(@" initial bigx %d xc %d,xoff %d width %d",x,xc,xoff,fonyWidth);
        int w = nw.intValue;
        if (firstField) firstX = xoff;
        //NSLog(@" parseHeaderColumns word [%@] xoff %d lastx %d firstx %d",wstr,xoff,lastX,firstX);
        
        if (xoff - lastX > 2*_glyphHeight && (lastX > 0))
        {
            //NSLog(@" got gap");
            firstField = TRUE;
            int aveX = (firstX + (lastX-firstX)/2);
            NSDictionary *dict = @{@"Field": hstr,@"X":[NSNumber numberWithInt:aveX]};
            [headerPairs addObject:dict];
            firstX = xoff;
            hstr = @"";
        }
        if (firstField)
            {hstr = wstr;
             //NSLog(@" firstfield %@",wstr);
            firstField = FALSE;
            }
        else
        {   //NSLog(@" append %@ to %@",wstr,hstr);
            hstr = [hstr stringByAppendingString:[NSString stringWithFormat:@" %@",wstr]];
        }

        lastX = xoff+w;
        
    }
    //DOn't need this now?? WTF???did above logic change that much!?
    int aveX = (firstX + (lastX-firstX)/2);
    NSDictionary *dict = @{@"Field": hstr,@"X":[NSNumber numberWithInt:aveX]};
    [headerPairs addObject:dict];
} //end parseHeaderColumns



//=============OCRDocument=====================================================
-(void) parseJSONfromDict : (NSDictionary *)d
{
    NSLog(@" Parsing JSON from dict...");
    [self clear];
    rawJSONDict   = d;
    NSArray *pr   = [d valueForKey:@"ParsedResults"];
    _numPages     = (int)pr.count;
    //Loop over our pages....
    int i=0;
    for (NSDictionary *dPage in pr)
    {
        [allWords removeAllObjects];
        NSMutableArray *Woids = [[NSMutableArray alloc] init];
        //NSString *parsedText = [dPage valueForKey:@"ParsedText"]; //Everything lumped together...
        NSDictionary *to     = [dPage valueForKey:@"TextOverlay"];
        NSArray *lines       = [to valueForKey:@"Lines"]; //array of "Words"
        for (NSDictionary *ddd in lines)
        {
            NSArray *words = [ddd valueForKey:@"Words"];
            for (NSDictionary *w in words) //loop over each word
            {
                OCRWord *ow = [[OCRWord alloc] init];
                [ow packFromDictionary:w];
                //[ow dump];
                [Woids addObject:ow];     // This is what gets copied to allPages...
                [allWords addObject:ow]; //Keep in structure, need to process stuff later
            }
        } //end for ddd
        [allPages addObject:Woids]; //Add next page ...
        NSLog(@" page %d : %d words",i,(int)Woids.count);
        i++;
    } //end for dpage..
    _numPages = i;
    [self getAverageGlyphHeight];
    [self assembleGroups];
    //NSLog(@" overall image wh %d,%d",_width,_height);
} //end parseJSONfromDict

//=============OCR VC=====================================================
// page is zero=based
-(void) setupPage : (int) page
{
    if (page<0 || page>= allPages.count) return;
    allWords = [allPages objectAtIndex:page];
} //end setupPage


//=============OCR VC=====================================================
// Used only when editing templates...
-(void) setupDocumentAndParseJDON : (NSString*) ifname : (NSDictionary *)d : (BOOL) flipped90
{
    _scannedImage = [UIImage imageNamed:ifname];
    _scannedName  = ifname;
    if (!flipped90)
    {
        _width        = _scannedImage.size.width;
        _height       = _scannedImage.size.height;
    }
    else
    {
        _height      = _scannedImage.size.width;
        _width       = _scannedImage.size.height;
    }

    [self parseJSONfromDict:d];
}

//=============OCR VC=====================================================
// Used in OCR batch runs...
-(void) setupDocumentWithRect : (CGRect) r : (NSDictionary *)d
{
    _scannedName  = @"nada";
    _width        = r.size.width;
    _height       = r.size.height;
    NSLog(@" od setupdoc wh %d %d",_width,_height);
    [self parseJSONfromDict:d];
}

//=============(OCRDocument)=====================================================
-(void) setPostOCRMinorError : (int) row : (int) merror
{
    if (row < 0 || row >= MAX_QPA_ROWS) return;
    postOCRMinorErrors[row] = merror;
}

//=============(OCRDocument)=====================================================
-(void) setPostOCRQPA : (int) row : (NSString*) q : (NSString*) p : (NSString*) a
{
    if (row < 0 || row >= MAX_QPA_ROWS) return;
    postOCRQuantities[row]  = q;
    postOCRPrices[row]      = p;
    postOCRAmounts[row]     = a;
} //end setQPA

//=============(OCRDocument)=====================================================
-(int) getPostOCRMinorError : (int) row
{
    if (row < 0 || row >= MAX_QPA_ROWS)  return 0;
    return postOCRMinorErrors[row];
} //end getPostOCRMinorError

//=============(OCRDocument)=====================================================
-(NSString*) getPostOCRQuantity : (int) row
{
    if (row < 0 || row >= MAX_QPA_ROWS)  return @"0.0";
    return postOCRQuantities[row];
}

//=============(OCRDocument)=====================================================
-(NSString*) getPostOCRPrice : (int) row
{
    if (row < 0 || row >= MAX_QPA_ROWS) return @"0.0";
    return postOCRPrices[row];
}

//=============(OCRDocument)=====================================================
-(NSString*) getPostOCRAmount : (int) row
{
    if (row < 0 || row >= MAX_QPA_ROWS)  return @"0.0";
    return postOCRAmounts[row];
}



//=============(OCRDocument)=====================================================
//  Called from OCR top object...
-(void) computeScaling:(CGRect )tlr : (CGRect )trr
{
//    [self setScalingRects];
    tlTemplateRect = tlr;
    trTemplateRect = trr;
    
    topmostLeftRect  = [self getLeftmostTopRect];
    topmostRightRect = [self getRightmostTopRect];
    //NSLog(@" tmleftRect %@",NSStringFromCGRect(topmostLeftRect));
    //NSLog(@" tmriteRect %@",NSStringFromCGRect(topmostRightRect));

    tlDocumentRect = [self getTLRect];
    trDocumentRect = [self getTRRect];
    blDocumentRect = [self getBLRect];
    brDocumentRect = [self getBRRect];
    _width  = (trDocumentRect.origin.x + trDocumentRect.size.width) - tlDocumentRect.origin.x;
    _height = (brDocumentRect.origin.y + brDocumentRect.size.height) - tlDocumentRect.origin.y;
    //NSLog(@"w/h computed %d %d",_width,_height);
    double hsizeTemplate   = (double)(trTemplateRect.origin.x + trTemplateRect.size.width) -
                         (double)(tlTemplateRect.origin.x);
    double hsizeDocument = (double)(topmostRightRect.origin.x + topmostRightRect.size.width) -
                         (double)(topmostLeftRect.origin.x);
    if (hsizeTemplate == 0 ||
        (hsizeTemplate != 0 && hsizeDocument == hsizeTemplate)) //unit scale or error!
    {
        hScale = vScale = 1.0;
        unitScale = TRUE;
    }
    else
    {
        hScale = vScale = hsizeDocument / hsizeTemplate;
        unitScale = FALSE;
    }
    NSLog(@" templateWid %f docWid %f  hvScale %f",hsizeTemplate,hsizeDocument,hScale);
    
} //end computeScaling




//=============(OCRDocument)=====================================================
-(int) doc2templateX : (int) x
{
    if (unitScale) return x;
    //DHS 12/31
    double bx = (double)x - (double)topmostLeftRect.origin.x;
    //...convert to template space...
    double outx;
    outx = (double)tlTemplateRect.origin.x + bx/hScale;
    //NSLog(@"  convx %f -> %f",bx,outx);
    return (int)floor(outx + 0.5);  //This is needed to get NEAREST INT!
}

//=============(OCRDocument)=====================================================
-(int) doc2templateY : (int) y
{
    if (unitScale) return y;
    //DHS 12/31
    double by = (double)y - (double)topmostLeftRect.origin.y;
    //...convert to template space...
    double outy;
    outy = (double)tlTemplateRect.origin.y + by/vScale;
    //NSLog(@"   convy %f -> %f",by,outy);
    return (int)floor(outy + 0.5);  //This is needed to get NEAREST INT!
}



//=============(OCRDocument)=====================================================
// Takes incoming Template box from a newly parsed document: needs to rescale this
//   box to match the OCR document space of boxes coming in.  Uses the two
//   Top / Left word boxes found in the Template and Document as anchor points and
//   the H/V scaling from computeScaling above
-(CGRect) doc2TemplateRect  : (CGRect) r
{
    if (unitScale) return r;
    // Get box XY offset in document space...
    double bx = (double)r.origin.x - (double)tlDocumentRect.origin.x;
    double by = (double)r.origin.y - (double)trDocumentRect.origin.y;
    //...convert to template space...
    double outx,outy,outw,outh;
    outx = (double)tlTemplateRect.origin.x + bx/hScale;
    outy = (double)tlTemplateRect.origin.y + by/vScale;
    outw = (double)r.size.width / hScale;
    outh = (double)r.size.height / vScale;
    
    CGRect rout = CGRectMake(outx, outy, outw, outh);
    
    //NSLog(@" gcr %@ -> %@",NSStringFromCGRect(r),NSStringFromCGRect(rout));
    
    return rout;
} //end getConvertedBox

//=============(OCRDocument)=====================================================
-(CGRect) template2DocRect  : (CGRect) r
{
    if (unitScale) return r;
    // Get box XY offset in template space...
    double bx = (double)r.origin.x - (double)tlTemplateRect.origin.x;
    double by = (double)r.origin.y - (double)tlTemplateRect.origin.y;
    //...convert to template space...
    double outx,outy,outw,outh;
    //DHS 12/31: OK try this as the origin???
    outx = (double)topmostLeftRect.origin.x + bx*hScale;
    outy = (double)topmostLeftRect.origin.y + by*vScale;
    outw = hScale * (double)r.size.width;
    outh = vScale * (double)r.size.height;
    
    CGRect rout = CGRectMake(outx, outy, outw, outh);
    
   // NSLog(@" t2dr %@ -> %@",NSStringFromCGRect(r),NSStringFromCGRect(rout));
    
    return rout;
} //end template2DocRect




/*-----------------------------------------------------------*/
/*-----------------------------------------------------------*/
double drand(double lo_range,double hi_range )
{
    int rand_int;
    double tempd,outd;
    
    rand_int = rand();
    tempd = (double)rand_int/(double)RAND_MAX;  /* 0.0 <--> 1.0*/
    
    outd = (double)(lo_range + (hi_range-lo_range)*tempd);
    return(outd);
}   //end drand



@end
