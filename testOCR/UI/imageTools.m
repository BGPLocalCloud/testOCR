//
//   _                           _____           _
//  (_)_ __ ___   __ _  __ _  __|_   _|__   ___ | |___
//  | | '_ ` _ \ / _` |/ _` |/ _ \| |/ _ \ / _ \| / __|
//  | | | | | | | (_| | (_| |  __/| | (_) | (_) | \__ \
//  |_|_| |_| |_|\__,_|\__, |\___||_|\___/ \___/|_|___/
//                     |___/
//
//  imageTools.m
//  testOCR
//
//  Created by Dave Scruton on 12/5/18.
//  Copyright © 2018 Beyond Green Partners. All rights reserved.
//

#import "imageTools.h"

@implementation imageTools

//=============(imageTools)=====================================================
-(UIImage *)convertOriginalImageToBWImage:(UIImage *)originalImage
{
    UIImage *newImage;
    
    CGColorSpaceRef colorSapce = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(nil, originalImage.size.width * originalImage.scale, originalImage.size.height * originalImage.scale, 8, originalImage.size.width * originalImage.scale, colorSapce, kCGImageAlphaNone);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextSetShouldAntialias(context, NO);
    CGContextDrawImage(context, CGRectMake(0, 0, originalImage.size.width, originalImage.size.height), [originalImage CGImage]);
    
    CGImageRef bwImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSapce);
    
    UIImage *resultImage = [UIImage imageWithCGImage:bwImage];
    CGImageRelease(bwImage);
    
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    [resultImage drawInRect:CGRectMake(0.0, 0.0, originalImage.size.width, originalImage.size.height)];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    return newImage;
}

//=============(imageTools)=====================================================
-(UIImage*)getHiContrast:(UIImage*)inputImage
{
    CIImage *coreImage = [[CIImage alloc] init];
    coreImage = [coreImage initWithImage:inputImage];
    
    NSNumber *workNumCont = [NSNumber numberWithFloat:1.2f];
    NSNumber *workNumSat  = [NSNumber numberWithFloat:0.0f];
    CIFilter *filterCont  = [CIFilter filterWithName:@"CIColorControls"
                                       keysAndValues: kCIInputImageKey,  coreImage,
                             @"inputSaturation", workNumSat,
                             @"inputContrast", workNumCont,
                             nil];
    CIImage *workCoreImage = [filterCont outputImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgimage = [context createCGImage:workCoreImage fromRect:[workCoreImage extent] format:kCIFormatRGBA8 colorSpace:CGColorSpaceCreateDeviceRGB()];
    UIImage *i = [UIImage imageWithCGImage:cgimage scale:0 orientation:[inputImage imageOrientation]];
    CGImageRelease(cgimage);
    return i;
}


//=============(imageTools)=====================================================
-(int) findLHEdge : (int) row
{
    int ptr = 4 * iwid * row; //RGB or RGBA?
    int count = 0;
    int found = 0;
    int iw2 = iwid/2;
    while (count < iw2 && found == 0)
    {
        int red = (int)idata[ptr];
        int red2 = (int) idata[ptr+4];
        int red3 = (int) idata[ptr+8];
        //if (row < 200) NSLog(@" row %d col %d : %d",row,count,red);
        if (red < 20 && red2 < 20 && red3 < 20) found = 1; //Dark pixel = hit!
        else
        {
            count++;
            ptr+=4;
        }
    }
    //if (row < 200) NSLog(@"............");
    if (found != 0) return count;
    return -1;
}

//=============(imageTools)=====================================================
// Find 3 dark pixels in a row...
-(BOOL) isItDark : (const UInt8*) idata : (int) ptr : (int) thresh
{
    int r1 = idata[ptr];
    int r2 = idata[ptr+4];
    int r3 = idata[ptr+8];
    //NSLog(@"  rgb[%d] %d,%d,%d,%d",ptr,idata[ptr],idata[ptr+1],idata[ptr+2],idata[ptr+3]);
    return (r1 < thresh && r2 < thresh && r3 < thresh);
}

//=============(imageTools)=====================================================
-(int) scanRowLToR : (const UInt8*) idata : (int) ptr : (int) wid : (int) thresh
{
    for (int i=0;i<wid;i++)
    {
        if ([self isItDark : idata : ptr : thresh]) return i; //Return column of hit
        ptr+=4;
    }
    return -1;
}

//=============(imageTools)=====================================================
-(int) scanRowLToRLite : (const UInt8*) idata : (int) ptr : (int) wid : (int) thresh
{
    for (int i=0;i<wid;i++)
    {
        int r1 = idata[ptr];
        int r2 = idata[ptr+4];
        //NSLog(@"  rgb[%d] %d,%d,%d,%d",ptr,idata[ptr],idata[ptr+1],idata[ptr+2],idata[ptr+3]);

        if (r1 < thresh && r2 < thresh) return i; //Return column of hit
        ptr+=4;
    }
    return -1;
}

//=============(imageTools)=====================================================
-(int) scanRowLToROnePixel : (const UInt8*) idata : (int) ptr : (int) wid : (int) thresh
{
    for (int i=0;i<wid;i++)
    {
        int r1 = idata[ptr];
        if (r1 < thresh) return i; //Return column of hit
        ptr+=4;
    }
    return -1;
}


//=============(imageTools)=====================================================
-(int) scanRowRToL : (const UInt8*) idata : (int) ptr : (int) wid : (int) thresh
{
    for (int i=0;i<wid;i++)
    {
        if ([self isItDark : idata : ptr : thresh]) return i; //Return column of hit
        ptr-=4;
    }
    return -1;
}



//=============(imageTools)=====================================================
-(void) findCorners : (UIImage *)workImage
{
    int x1,y1,x2,y2;
    pixelData = CGDataProviderCopyData(CGImageGetDataProvider(workImage.CGImage));
    if (pixelData == nil) return;
    idata = CFDataGetBytePtr(pixelData);
    iwid = workImage.size.width;
    ihit = workImage.size.height;
    //NSLog(@" image wh %d %d",iwid,ihit);
    //Top left...
    BOOL found = FALSE;
    int row,col;
    int verticalTestLimit = ihit/4;
    row = col = 0;
    for (row=0;row<verticalTestLimit && !found;row++) //Go down from top
    {
        int ptr = iwid * 4 * row;
        col = [self scanRowLToR:idata :ptr :iwid/10 : 40];
        if (col != -1) found = TRUE;
    }
    x1 = col;
    y1 = row;
    found = FALSE;
    //NSLog(@"topLeft %d,%d",col,row);
    //Top right...
    for (row=0;row<verticalTestLimit && !found;row++) //Go down from top
    {
        int ptr = iwid * 4 * (row + 1) - 8; //second to last pixel on row...
        col = [self scanRowRToL:idata :ptr :iwid/10 : 40];
        if (col != -1)
        {
            col = iwid - col;
            found = TRUE;
        }
    }
    
    x2 = col;
    if (row < x1) x1 = row;
    //NSLog(@"topRight %d,%d",col,row);

    //Bottom Left...
    found = FALSE;
    for (row=ihit-1;row>ihit - verticalTestLimit && !found;row--) //Go up from bottom
    {
        int ptr = iwid * 4 * row; //second to last pixel on row...
        col = [self scanRowLToR:idata :ptr :iwid/10 : 40];
        if (col != -1)
        {
            found = TRUE;
        }
    }
    if (col < x1) x1 = col; //Keep LH most column
    y2 = row;
    NSLog(@" image wh %d %d corners: x1,y1 %d,%d  : x2,y2 : %d,%d",iwid,ihit,x1,y1,x2,y2);
    ix1 = x1; //Save results into our object here
    ix2 = x2;
    iy1 = y1;
    iy2 = y2;
    
} //end findCorners


//=============(imageTools)=====================================================
-(UIImage *) deskew : (UIImage *)workImage
{
    NSLog(@" deskew");
    
    pixelData = CGDataProviderCopyData(CGImageGetDataProvider(workImage.CGImage));
    if (pixelData == nil) return nil;
    idata = CFDataGetBytePtr(pixelData);
    iwid = workImage.size.width;
    ihit = workImage.size.height;
    int i;
    for (i=0;i<MAXBINS;i++)
    {
        bins[i]         = -1;
        binclumpaves[i] = -1;
        bgrad[i]        = -1;
        absgrad[i]      = -1;
        leftVline[i]    = -1;
    }
    int bcount = 0;
    //Find LH edges...
    for (int row=0;row<ihit;row++) //Go all the way down from top
    {
        int ptr = iwid * 4 * row;
        int col = [self scanRowLToROnePixel:idata :ptr :iwid/2 : 120];
        bins[bcount++] = col;
        NSLog(@" rawbin [%d] = %d",bcount-1,col);
    }
    
    //Try to find a straight line along the LH side FIRST....
    int oldx = -1;
    int newx = -1;
    //int ledge = -1;
    int topledge = ihit*0.25;
    int botledge = 0.75*ihit;
    for (int row=topledge;row<botledge;row++) //Middle 50%
    {
        
        newx = bins[row];
        if (oldx != -1)
        {
            if (abs(newx - oldx) < 2) //straight edge?
            {
                leftVline[row] = bins[row];
                NSLog(@" ll[%d] = %d",row,bins[row]);
            }
        }
        oldx = newx;
    }
    
/*
    //Smooth leftvline
    int dog = 0;
    for (int row=topledge + 3;row<botledge;row++) //Middle 50%
    {
        if(leftVline[row-1] > 0 && leftVline[row-2] > 0)
        {
            int ave = leftVline[row] + leftVline[row-1] + leftVline[row-2];
            ave = ave/3;
            leftVline[row] = ave;
            leftVline[row-1] = ave;
            leftVline[row-2] = ave;
            NSLog(@" ll2 [%d] = %d",row,ave);
        }
    }
*/
    
    int firstMin = 9999;
    int minAtTop = 1;
    //find a minimum at the start
    for (int i=topledge;i<botledge;i++)
    {
        if ((leftVline[i] > 0) && (leftVline[i] < firstMin))
        {
            firstMin = leftVline[i];
            if (i > bcount / 2) minAtTop = 0;
        }
    }
    
    NSLog(@" firstmin %d minattop %d",firstMin,minAtTop);


    //Now toss any bins that aren't near this minimum, also follow it up or down
    int bigBinThresh = 10;
    for (int i=topledge;i<botledge;i++)
    {
        int nm = leftVline[i];
        if (abs(nm - firstMin) > bigBinThresh) bins[i] = -1;
        else
        {
            firstMin = nm;
            bins[i] = leftVline[i];  //not nearby? Toss! or copy back to bins
        }
    }
    
    //OK LEFT EDGE -> bins now!!
    // Next, find local minima and flatten them down...
    for (int pass = 0;pass<2;pass++)
    {
        for (int i=topledge;i<botledge;i++)
        {
            if (bins[i-1] > 0 && bins[i+1] > 0) //Got valid neighbors?
            {
                int tval = bins[i];
                if (tval < bins[i-1] && tval < bins[i+1]) //this bin smaller than neighbors? shrink neighbors
                {
                    bins[i-1] = tval;
                    bins[i+1] = tval;
                }
                else if (tval > bins[i-1] && tval > bins[i+1]) //this bin bigger than neighbors? shrink this bin
                {
                    int nval = bins[i-1];
                    if (bins[i+1] < nval) nval = bins[i+1];
                    bins[i] = nval;
                }
            }
        }

    }
    
    //Now find start / end bin limits
    int sbin = -1;
    int ebin = -1;
    int minbin = 99999;
    //Get smallest bin size in top 10% of document
    int ledgeDiff = botledge - topledge;
    for (int i=topledge;i<topledge+ledgeDiff/10;i++)
    {
        int bval = bins[i];
        if ((bval > 0) && bval < minbin)
        {
            NSLog(@" Top minbin %d = %d",i,bval);
            sbin   = i;
            minbin = bval;
        }
    }
    NSLog(@" minfound %d",minbin);


    int maxbin = -99999;
    for (int i=topledge + ledgeDiff*0.9;i<botledge;i++)
    {
        int bval = bins[i];
        if ((bval > 0) && bval > maxbin)
        {
            ebin   = i;
            maxbin = bval;
        }
    }

    //Get smallest bin size in bottom 10% of document
    double sum = 0.0;
    int scount = 0;

    for (int i=topledge;i<topledge + ledgeDiff*0.1;i++)
    {
        if (bins[i] >0)
        {
            NSLog(@" TOPPP  i %d bin %d",i,bins[i]);
            sum+=(double)bins[i];
            scount++;
        }
    }
    int topAve =  floor((sum / (double)scount) + 0.5);
    sum = 0.0;
    scount = 0;
    for (int i=topledge + ledgeDiff*0.9;i<botledge;i++)
    {
        if (bins[i] >0)
        {
            NSLog(@" BOTTTTTOM  i %d bin %d",i,bins[i]);
            sum+=(double)bins[i];
            scount++;
        }
    }

    int botAve =  floor((sum / (double)scount) + 0.5);
    NSLog(@" top/bot ave %d %d",topAve,botAve);

    NSLog(@" sbin[%d]=%d  ebin[%d]=%d",sbin,bins[sbin],ebin,bins[ebin]);


    double ddx = (double)(ebin - sbin);
    double ddy = (double)(bins[ebin] - bins[sbin]);
    
    ddx = 559 - 166;
    ddy = 23 - 21;
    double angle2 = atan2f(ddy, ddx);
    _skewAngleFound = angle2;
    NSLog(@" start/end bins %d %d  vals %d %d   annnnd angle %f",sbin,ebin,bins[sbin],bins[ebin],_skewAngleFound);
    //float adeg  = 360.0 * (angle / (2 * 3.14159));
    return [self imageRotatedByRadians:angle2 img:workImage];
} //end deskew


//=============(imageTools)=====================================================
- (UIImage *)imageRotatedByRadians:(CGFloat)radians img:(UIImage *)img
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,img.size.width, img.size.height)];
    UIView *nonrotatedViewBox = rotatedViewBox;
    CGAffineTransform t = CGAffineTransformMakeRotation(radians);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(nonrotatedViewBox.frame.size);
    //Fill in bkgd with white
    CGColorRef whiteColor = [[UIColor whiteColor] CGColor];
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShouldAntialias(context, NO);
    CGContextSetInterpolationQuality( UIGraphicsGetCurrentContext() , kCGInterpolationNone );
    CGContextSetFillColorWithColor(context, whiteColor);
    CGContextFillRect(context, CGRectMake(0,0,rotatedSize.width,rotatedSize.height));

    
    
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //Rotate the image context
    CGContextRotateCTM(bitmap, radians);
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-img.size.width / 2, -img.size.height / 2, img.size.width, img.size.height), [img CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}



//=============(imageTools)=====================================================
-(UIImage *)rotate90CCW:(UIImage *)workImage
{
    double PI_OVER_TWO = -1.5707963135;
    return [self imageRotatedByRadians:PI_OVER_TWO img:workImage];

}



//=============(imageTools)=====================================================
-(UIImage *)pdfToImage: (CGPDFPageRef) pdfPage

{
    CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFMediaBox);
    CGFloat pdfScale = 1.0;   //width/pageRect.size.width;
    
    NSLog(@" PdF size %d x %d",(int)pageRect.size.width,(int)pageRect.size.height);
    pageRect.size = CGSizeMake(pageRect.size.width*pdfScale, pageRect.size.height*pdfScale);
    pageRect.origin = CGPointZero;
    
    
    UIGraphicsBeginImageContext(pageRect.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // White BG
    CGContextSetRGBFillColor(context, 1.0,1.0,1.0,1.0);
    CGContextFillRect(context,pageRect);
    
    CGContextSaveGState(context);
    
    // ***********
    // Next 3 lines makes the rotations so that the page look in the right direction
    // ***********
    CGContextTranslateCTM(context, 0.0, pageRect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(pdfPage, kCGPDFMediaBox, pageRect, 0, true));
    
    CGContextDrawPDFPage(context, pdfPage);
    CGContextRestoreGState(context);
    
    UIImage *thm = UIGraphicsGetImageFromCurrentImageContext();
    NSLog(@" annnnd imagesize %d x %d",(int)thm.size.width,(int)thm.size.height);
    
    UIGraphicsEndImageContext();
    return thm;
    
}



@end
