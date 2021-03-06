//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// NOTE: This is the OOGIE-2 (OOGIETWOOGIE) version of SynthDave!
//         It is no longer campatible with OOGIE, at the very least it should 
//           be used with CAUTION with older OOGIE stuff....
//
//    ____              _   _     ____                  
//   / ___| _   _ _ __ | |_| |__ |  _ \  __ ___   _____ 
//   \___ \| | | | '_ \| __| '_ \| | | |/ _` \ \ / / _ \
//    ___) | |_| | | | | |_| | | | |_| | (_| |\ V /  __/
//   |____/ \__, |_| |_|\__|_| |_|____/ \__,_| \_/ \___|
//           |___/                                      
//				 
//  product number: 495032459
//
//  DHS 4/27: Added square/sine/ramp/saw waves plus selector
//  DHS 5/6: Added NoiseWave and NoiseWaveBmp  button
//  DHS 5/27-6-1: OK, we read samplefiles herein, too. 
//       For now, we'll stick to 11025Hz/1Channel/UnsignedShort!
//  OK, big change.  All synths/samples get loaded into the same
//    set of buffers; all voices are loaded at once.  Udderwise,
//    we could never have synth AND sample polyphony.....
//  Each Synth needs to have an ADSR table, at the very least as well...
//  DHS June 9: fixed squelchy noise problem: added level clamping 
//        AFTER mixing, not before!!
//  DHS June 12: Added stereo support. Each Tone can be panned L/R/C/etc...
//     use globals glpan and grpan, then store them w/ tone in playnote
//  DHS August Bayonne: Couple new features to support multi-sample
//       (above percussion) playing.  Added releaseAllNotesByWaveNum
//  DHS August 18: Got Synth detune (for samples) and threhold working...
//  9/6  : Fixed double click bug. Was in releaseallnotes
// here's where setups live...
///Users/davescruton/Library/Application Support/iPhone Simulator/4.3/Applications/8AB8FC63-5841-40FE-A55C-244A78DB38DB/tmp/oogfile4.txt
// 11/9: Added "mono" property to tones...
//  11/27: Add NULL in buildAWaveTable to try fixing mem leaks...
// 12/14: BUG FIX! After tons of testing, deleting a note could cause a crash
//          if note was still ringing out! Fixed that at place where sbufs get freed...
//  Nov 27 2012: Fixed bug creating synth voices, needed check for sEnvs in fillbuffer.
//  DHS 1/8/13: was mixing float/type in use of sampleRate! bad!
//               revamped usage of envIsUp and envLength, both become arrays
//       ...still see spurious "zero env length" errors! WHY?
//  DHS 1/19/13: Added note queueing, look for "queue"
//  DHS 2/13/13: Added gain,mono,pan,port to notequeue, was missing!
//                 implemented portamento
//                Redid note finder in playnote
//  DHS 2/20/13: Port seems better, but now no sound when OFF?
//  DHS 2/23/13: Add recording/reclength flags, try to make WAV file...
//  DHS 4/3/13:  Added limit checks to prevent zero record time. 
//  DHS 4/10/13: Added master Level
//  DHS 4/29/13: Trying to load .wav file from WEB, doesn't work yet!
//                  keep getting err -43, file not found even though it exists!
//               see loadSample
//  DHS 5/7/13:  Changed buildenvelope so it frees envelope storage on
//                 repeat calls to same voice/envelope number. 
//               Otherwise, a reset was causing envelope errors upon
//                 creation of new voices afterwards...
//  DHS 5/10/13: Add new param, timetrax
// DHS May 19: OOGIE speaks MIDI! Makes killer sounds!
//               there may be too many MIDI note off's getting sent?!?!
// DHS May 30-31: READY FOR RELEASE?
//              I tried changing fileID ref's in loadSample to get rid of
//              compiler warnings, but it resulted in good reads but silent
//              samples! So I put it back the old way. FUCK IT.
//=========================================================================
// APP submittal to Apple, June 13th!!!
//=========================================================================
// DHS 6/14/13 : POST-SUBMITTAL BUG!
//               Pitches array was dimmed 128, but with higher octaves
//                we could get a note bigger than 128. Zero/garbage pitch!
//               Redimmed to 256
//               Commented out portomento block
// DHS 6/29/13 : Add unique count to each voice and tone, 
//               Mono is ok now with cloned voices
// DHS 7/13/13: Add redundancy check in startRecording...
// DHS 8/9/13:  BIG CHANGE in oogiecam version:
//               Uniquenum gets incremented every note play.
//               Uniquenum is no longer stored in queue.
//               Also, fadeout logic changed, and waveNum gets set to -1
//                when a note's state goes inactive...
//  DHS 12/30/13: Re-did sample loading offsets, VERY different from
//                main oogiepad s/w now! BEWARE!
// January 2014!!!
//   IOS-7 ONLY version, with Auto Reference Counting on. NO releases allowed!
//            extensive use of the __bridge operator are required...
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// OOGIECAM VERSION:
//  DHS 8/9/13: First Release? WOW! Within a week from inception!
//  DHS Jan 23 2014: Version for ARC-based RoadieTrip!
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// HUEDOKU VERSION:
//  DHS 11/27/14: Force load all samples as stereo.
//                Still need to change fillbuffer: CRASHED first try! .....Pulled mono switching from fillbuffer
// DHS 3/16/15:  Added playNoteWithDelay...
//                Changed queue dims!
// DHS 11/12     removed * in AudioFileID fileID declaration
//               replaced AudioFileReadPackets with AudioFileReadPacketData
// DHS 4/18/12:  For some reason RECORDING WAS on all the time! Disabled!
// DHS 7/27/17:  Pulled spurious call to buildaWaveTable in init...
//               Also added check for sBuf != NULL explicitly in buildSampleTable
#import <QuartzCore/CABase.h>
#import "SynthDave.h"
#include "oogieMidiStubs.h"
#include <time.h>
#include "cheat.h"

//SPECIAL ARC flag, set this if we are NOT using ARC
#define ARC_OFF



int midion = 1;

float ATTACK_TIME   = 0.004f;
float DECAY_TIME    = 0.002f;
float SUSTAIN_LEVEL = 0.8f;
float SUSTAIN_TIME  = 0.04f;
float RELEASE_TIME  = 0.05f;
float DUTY_TIME     = 0.5f;
float SAMPLE_OFFSET = 0.0f;
@interface Synth (Private)
- (void)equalTemperament;
@end

#define SYNTH_TS 500.0  // was 1000 Converts percentage synth params to real-time...
//several sets of 12-key lookup tables, used to convert
//  chromatic musical input so it sounds "in tune"...

int keysiglookups[] ={
	0,0,2,2,4,5,5,7,7,9,9,11,		// Major
	0,0,2,3,3,5,5,7,8,8,10,10,		// Minor
	0,0,2,2,4,6,6,7,7,9,9,11,		//Lydian
	0,1,1,4,4,5,7,7,8,8,10,10,		//Phrygian
	0,0,2,2,4,5,5,7,7,9,10,10,		//Mixolydian
	0,1,1,3,3,5,6,6,8,8,10,10,		//Locrian
	0,2,2,3,3,6,6,7,8,8,11,11,		//Egyptian
	0,1,1,4,4,5,5,7,8,8,11,11,		//Hungarian
	0,0,2,3,5,5,6,7,8,8,11,11,		//Algerian
	0,0,2,2,5,5,5,9,9,9,10,10,		//Japanese
	0,0,0,4,4,4,6,6,7,7,11,11,		//Chinese
	0,1,2,3,4,5,6,7,8,9,10,11,		//Chromatic
};

double drand(double lo_range,double hi_range );


//PULL these vars into class private area...
int uniqueVoiceCounter;   //set to 0, increments every time playnote is called...
int monoLastUnique;

int gotSample,sampleSize;



@implementation Synth

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(int)isRecording
{
	return recording;
    
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void)startRecording:(int)newlen
{
    //DHS 7/13/13
    if (recording) return;
    if (newlen == 0)
    {
    //    NSLog(@" ERROR! zero record length! ...default to 5 secs");
        newlen = 5;
    }
     reclength = newlen;
    //OK, we need to alloc. a buffer!
    recsize = newlen * 11025 * 2 * sizeof(short);
    //NSLog(@"...record %d secs, alloc %d bytes audioRecBuffer",newlen,recsize);
    audioRecBuffer = (short *)malloc(recsize);
//    if (0 && audioRecBuffer != NULL)
//    {
//     //NSLog(@" ...alloc %d bytes OK, buffer %x",recsize,(unsigned int)audioRecBuffer);   
//    }
    recptr=0;
    recording = 1;
} //end startRecording

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// stops recording, writes if cancel is zero
-(void)stopRecording:(int)cancel
{
    if (!recording) return;
    if (!cancel)
    {
       //NSLog(@" ...done recording, write output...");   
        //WRITE FILE HERE
        [self writeOutputSampleFile:@"dog.caf":@".caf"];
    }
    if (audioRecBuffer)  //clear storage
    {
        free(audioRecBuffer);
        audioRecBuffer=NULL;
    }
    recording=0;
    //need to stop and save/nosave samplefile
} //end stopRecording


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (id)initWithSampleRate:(float)sampleRate_
{
	int loop;
    //NSLog(@"  initWithSampleRate : %f",sampleRate_);
	if ((self = [super init]))
	{
		sampleRate          = (float)sampleRate_;
        //NSLog(@" init all, samplrate %f",sampleRate);
		gain                = 0.59f; //OVERall gain factor
		finalMixGain        = 1.0;
		gotSample           = 0;
		swave               = NULL; //temp sample file storage....
        swaveSize           = 0;
		glpan = grpan       = 0.5;  //set to center pan for now
        gportlast           = 64;  //last note; default to center of keyboard        
        uniqueVoiceCounter  = 0; 
        monoLastUnique      = 0;
        masterLevel         = 1.0;
        timetrax            = 0;
        queuePtr            = 0; //DHS 1/19 start with empty note queue
        arpPtr              = 0; //DHS 3/16/15: Arpeggiator...
        arpPlayPtr          = 0; //DHS 3/16/15: Arpeggiator...
        newUnique           = 0;
        aFactor             = 0.0f;
        bFactor             = 0.0f;
        recording = reclength = recptr = recsize = 0;
        //NSLog(@" null out audioRecBuffer...");
        audioRecBuffer = NULL;       
        recFileName = NULL;
        needToMailAudioFile=0;
		LOOPIT(MAX_SAMPLES)
		{
			sBufs[loop]		= NULL;
            //NSLog(@" clear sbuf[%d] %@",loop,sBufs[loop]);
			sBufLens[loop]  = -1;		
			sBufChans[loop] = -1;		
			sEnvs[loop]		= NULL;
            sElen[loop]     = 0;
            envIsUp[loop]   = 0;
            envLength[loop]   = 0;
		}
		LOOPIT(MAX_TONE_EVENTS)tones[loop].state = STATE_INACTIVE;		

		[self equalTemperament];
		//OK get our wave setup and built
		sineLength = 2 * (int)sampleRate;
        //DHS 7/27 WHY???		[self buildaWaveTable: 0:1];
        //DHS 11/20: Seed our random generator w/ current time
        srand((unsigned int)time(NULL));
        numSVoices = 0;
        numPVoices = 0;
        
        LOOPIT(16) lvolbuf[loop]=0.0;
        LOOPIT(16) rvolbuf[loop]=0.0;
        lrvolptr=lrvolmod=0;
        
        arptimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(arptimerTick:) userInfo:nil repeats:YES];

	}

    
	return self;
} //end initWithSampleRate


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)dealloc
{
	int loop;
    //NSLog(@" dealloc: Free all");
	if (swave != NULL) 
	{
		free(swave);
        swaveSize = 0;
		swave = NULL;
	}
	LOOPIT(MAX_SAMPLES)
	if (sBufs[loop] != NULL)
	{
		free(sBufs[loop]);
		sBufs[loop] = NULL;
	}
	LOOPIT(MAX_SAMPLES)
	if (sEnvs[loop] != NULL)
	{
		free(sEnvs[loop]);
		sEnvs[loop] = NULL;
        sElen[loop] = 0;
	}
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(void) dumpAudioBuffer : (int) which : (int) size
{
    NSLog(@"Dump sbuf[%d]",which);
    for (int i=0;i<size;i++)
    {
        NSLog(@" [%.4d]:%f",i,sBufs[which][i]);
    }
    
}

-(void) testit1
{
    NSLog(@" copy some of buf 0 -> buf 1");
    int isize = sBufLens[0];
    if (sBufLens[1] > isize) isize = sBufLens[1];
    if (isize > 4096) isize = 4096;
    for (int i=0;i<isize;i++)
    {
        sBufs[1][i] =  sBufs[0][i];
    }
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)arptimerTick:(NSTimer *)timer
{
    
    if (arpPlayPtr != arpPtr)  //IS there some stuff to play?
    {
        double latestTime = CACurrentMediaTime();
        int latestdelay   = arpQueue[ARP_PARAM_TIME][arpPlayPtr];
        double isitTime   = arpTime + (double)latestdelay/1000.0; //Add ms delay..
        if (latestTime > isitTime) //Time to play!
        {
            int a,b,c;
            a         = arpQueue[ARP_PARAM_NOTE][arpPlayPtr];
            b         = arpQueue[ARP_PARAM_WNUM][arpPlayPtr];
            c         = arpQueue[ARP_PARAM_TYPE][arpPlayPtr];
            gain      = arpQueue[ARP_PARAM_GAIN][arpPlayPtr];
            mono      = arpQueue[ARP_PARAM_MONO][arpPlayPtr];
            glpan     = arpQueue[ARP_PARAM_LPAN][arpPlayPtr];
            grpan     = arpQueue[ARP_PARAM_RPAN][arpPlayPtr];
            //NSLog(@" arp delay %d note %d %d %d at %f lt %f izit %f",latestdelay,a,b,c,arpTime,latestTime,isitTime);
            [self playNote:a:b:c];
            arpPlayPtr++;
            if (arpPlayPtr >= MAX_ARP) //Wraparound!
                arpPlayPtr = 0;
            arpTime  = latestTime;
        }
    }
} //end arptimerTick

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets a range of plus/minus one-half semitone
- (void)setMasterTune:(int)nt;
{
    masterTune = (float)nt/10.0;
} //end setMasterTune

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets a range of plus/minus one-half semitone
- (void)setMasterLevel:(float)nl;
{
    masterLevel = nl;
    //NSLog(@" synth set master level %f",nl);
} //end setMasterLevel

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//  OK: assume A4 on musical keyboard is at 440Hz.
//    this then builds a set of pitches based on
//    12-semitone equitonal octaves......
- (void)equalTemperament
{
    //NSLog(@"Synth: set equalTemperament, tune %f",masterTune);
	for (int n = 0; n < 256; ++n)
		pitches[n] = 440.0f * powf(2, ((float)n + masterTune - 69.0)/12.0f);  // A4 = MIDI key 69

    //pitches[n] = 440.0f * powf(2, (n - 69)/12.0f);  // A4 = MIDI key 69

}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// builds one of 'which' waves: Ramp,Sine, Saw, Square  ...+??
// Wave gets stored in the sBuf sample buffer, indexed by which
- (void)buildaWaveTable: (int) which :(int) type
{
	//int loop;
	if (sBufs[which] != NULL) //already got sumthin??? 
	{
        [self cleanupNotes:which];
         free(sBufs[which]);
        sBufs[which] = NULL;
	}

    //NSLog(@"  buildwave %d type %d",which,type);
	switch(type)
	{
		case 0: [self buildRampTable:which];
			break;
		case 1: [self buildSineTable:which];
			break;
		case 2: [self buildSawTable:which];
			break;
		case 3: [self buildSquareTable:which];
			break;
        case 4: [self buildNoiseTable:which];
			break;
		case 5: [self buildSinXCosYTable:which];
            break;
        default: [self buildRampTable:which];
			break;
	}
	//if(0) for(int i=0;i<sineLength;i+=256)
	// 	NSLog(@" wav[%d] %f",i,sBufs[which][i]);
			
	// NSLog(@"  bwte %d",which);
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildNoiseTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++) //one wavelength for the ramp, k?
		sBufs[which][i] = (float)drand(0.0,1.0 );
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildRampTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++) //one wavelength for the ramp, k?
		sBufs[which][i] = (float)i / sineLength;
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSawTable: (int) which
{
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	int sl2 = sineLength/2;
	for (int i = 0; i < sl2; i++) //one half wavelength for the saw, k?
		sBufs[which][i] = 2.0 * (float)i / sineLength;
	for (int i = sl2; i < sineLength; i++) //2nd half
		sBufs[which][i] = 1.0 - sBufs[which][i-sl2];
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSquareTable: (int) which
{
	int i,duty = DUTY_TIME * sineLength;
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for ( i = 0; i < duty; i++)  //first half is 0
		sBufs[which][i] = 0.0;
	while (i < sineLength)  //second half is  1 (what about dutyy??)
		sBufs[which][i++] = 1.0;
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildSineTable: (int) which
{
	// Compute a sine table for a 1 Hz tone at the current sample rate.
	// We can quickly derive the sine wave for any other tone from this
	// table by stepping through it with the wanted pitch value.
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
	for (int i = 0; i < sineLength; i++)
	{
		sBufs[which][i] = sinf(i * 2.0f * M_PI / sineLength);
	}
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
	return;
} //end buildSineTable



/*==waves....==================================*/
/*=============================================*/
- (void)buildSinXCosYTable: (int) which
//void sinxcosyWave(int a,int b,int c,int d,double *wave)
{
    int a,b;
	//int loop;
	double c1,c2;
    double WSIZE = sineLength;
	//c=d=0;
	sBufs[which] = malloc(sineLength * sizeof(float));
	if (!sBufs[which]) return;
    a  = (int)aFactor;
    b  = (int)bFactor;
	c1 = 0.5;     //127.5;
	c2 = 0.4999;  //127.0;
	a = max(1,a);
	b = max(1,b);
  //  LOOPIT(WSIZE) wave[loop] =
  //  (c1+ c2*
  //   (double)sin(3.*(double)(loop*a)/WSIZE)*
  //   (double)sin(3.*(double)(loop*b+128)/WSIZE)
  //   );
	for (int i = 0; i < sineLength; i++)
	{
		sBufs[which][i] = //  sinf(i * 2.0f * M_PI / sineLength);
          (c1 + c2*
            (double)sin(3.*(double)(i*a)/WSIZE)*
            (double)sin(3.*(double)(i*b+128)/WSIZE)
            );

        //NSLog(@" sinxcosy[%d] %f",i,sBufs[which][i]);
	}
	sBufLens[which] = sineLength;
	sBufChans[which] = 1;
    
} //end sinxcosyWave

/*==waves....==================================*/
/*=============================================*/
- (void)buildSinXSinYTable: (int) which
//void sinxsinyWave(int a,int b,int c,int d,double *wave)
{
    int loop;
    int a,b;
    double WSIZE = (double)sineLength;
	double c1,c2;
	a=b=0;
	c1 = 127.5;
	c2 = 127.0;
    a = max(1,a);
    b = max(1,b);
    LOOPIT(WSIZE) sBufs[which][loop] =
    (c1 + c2*
     (float)sin(3.*(float)(loop*a)/WSIZE)*
     (float)sin(3.*(float)(loop*b)/WSIZE));
}  //end sinxsinyWave


/*==waves....==================================*/
/*=============================================*/
- (void)buildSinOSineTable: (int) which
//void sinosineWave(int a,int b,int c,int d,double *wave)
{int loop,ival1;
	double c1,c2;
    int a,b,c;
    double WSIZE = (double)sineLength;
	c1 = 127.5;
	c2 = 127.0;
	a=b=c=0;
    a = max(1,a);
    b= max(1,b);
    LOOPIT(WSIZE)
    //THIS IS BROKEN. MOD WON'T WORK ON DOUBLES!
    { ival1 =  (loop*a) + (int)((float)b*(1.0+
                                          (float)sin(3.*(float)((loop*c)%(int)WSIZE))));
       sBufs[which][loop] =
        (c1+c2*
         (float)sin(3.*(float)(ival1%(int)WSIZE)));
    }
} //end sinosineWave




//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// this assumes swave has been populated w/ samplefile contents...
//  (ALSO ASSUME ONLY MONO FOR NOW!!!
// DHS TGIVING 14: Force stereo samples: makes playback faster
- (void)buildSampleTable:(int)which
{
    int err=0;
	Float32 cFrame;
	short ts;
	int i;
    //NSLog(@" buildSampleTable %d",which);
	if (sBufs[which] != NULL) //DHS 7/27 Added NULL comparison
    {
        //NSLog(@"  Free sbufs[%d] %@",which,sBufs[which]);
        [self cleanupNotes:which];
        free(sBufs[which]); //no illegal double-alloc, please...   
        sBufs[which] = NULL;
    }
     //NSLog(@"  Malloc sbufs[%d] size %d",which,sNumPackets);
	sBufs[which] = malloc(sNumPackets * 2 * sizeof(float));
//DHS OLD	sBufs[which] = malloc(sNumPackets * sChans * sizeof(float));
	if (!sBufs[which]) return;
	//  NSLog(@" buildsample[%d]: size %d",which,sNumPackets*sChans);

	//OOGIE CRASH here when I add sample#14, oogierap!
    //  which is 51!
    for ( i = 0; i < sNumPackets*sChans; i+=sChans)  // step through by #channels per packet
	{	
        if (i >= swaveSize) 
        {
            //NSLog(@" ...illegal sample build: index %d maxsize %d",i,swaveSize);
            err=1;
            break;   
        }
		memcpy(&ts,&swave[i],2);  //dest,source,len...
		cFrame = (float)ts / 32768.0f;
		sBufs[which][i] = cFrame; //store our data...
        //if (i < 4) NSLog(@"  ...cframe[%d] %f",i,cFrame);
//DHS OLD		if (sChans == 2)
		{
            if (sChans == 1)
                memcpy(&ts,&swave[i],2);  //dest,source,len...
            else
                memcpy(&ts,&swave[i+1],2);  //dest,source,len...
			cFrame = (float)ts / 32768.0f;
			sBufs[which][i+1] = cFrame; //store our data...
		}
		//if (0 &&  i%128 == 0)
		//	NSLog(@" bsw[%d] swave %d ts %d cFrame %f",i,swave[i],ts,cFrame);
	}
	sBufLens[which] = sNumPackets*sChans;
    if (err) sBufLens[which] = 8192; //STOOPID SIZE!
//DHS OLD	sBufChans[which] = sChans;
	sBufChans[which] = 2;
	return;
} //end buildSampleTable


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)buildEnvelope:(int)which 
{
	// All envelopes are same length, with data from 0.0 to 1.0. 
	//  Each synth voice will have a corresponding envelope? 
	// Because lower tones last longer than higher tones, we will use a delta
	// value to step through this table. MIDI note number 64 has delta = 1.0f.
	float envsave;
	int i,savei,esize;
	int attackLength, decayLength , sustainLength, releaseLength;
    //NSLog(@"1>>> buildenv w %d sr %f isup %d",which,sampleRate,envIsUp[which]);
    //envelope was in use? Clobber it!
    if (sEnvs[which] != NULL)
    {
        //NSLog(@"  ...free env %d...",which);
        free(sEnvs[which]);
        sEnvs[which] = NULL;
    }
	if (1)  
	{
		envLength[which] = (int)sampleRate * 2;  // 2? seconds DHS MAKE IT BIG
		envIsUp[which] = 1;
	}
    //NSLog(@"2>>> senvs %d  length %d",(int)sEnvs[which],envLength[which]);
    if (envLength[which]) //Legal Envelope length? getit
	{
        esize = envLength[which]*sizeof(float);
		sEnvs[which] = (float*)malloc(esize);
		if (!sEnvs[which]) return;
        sElen[which] = esize;
        //NSLog( @" alloc senv[%d]",which);
	}
    else {
        //NSLog(@" error in buildEnvelope: zero env length, which %d",which);
        return;
    }
    //NSLog(@"  build env %d len %d...",which,envLength[which]);
	
	attackLength  = (int)(ATTACK_TIME  * sampleRate);  // attack
	decayLength   = (int)(DECAY_TIME   * sampleRate);  // decay
	sustainLength = (int)(SUSTAIN_TIME * sampleRate);  // sustain
	releaseLength = (int)(RELEASE_TIME * sampleRate);  // release
//	NSLog(@" TOP ADSR============= %d %d %d %d %f",
//		  attackLength,decayLength,sustainLength,releaseLength ,sampleRate);

	if (attackLength < 1)
	{		
		i = 0;
		envsave = 1.0;
	}
	else  
	{
		for (  i = 0; i < attackLength; i++)
			{
                if (i > sElen[which]) break;   //OUCH! Shouldn't happen
				sEnvs[which][i] = (float)i / (float)attackLength;
				//NSLog(@" ...Aenv[%d] %f",i,sEnvs[which][i]);
			}
		envsave = sEnvs[which][i-1]; //save last env level...
	}
	savei = i;
	// NSLog(@" ...Denvtop[%d] %d %f %d %f %f",which,savei,envsave,decayLength,sampleRate,SUSTAIN_LEVEL);
	for (  i = savei; i < (savei + decayLength); i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = envsave - ((float)(1.0 - SUSTAIN_LEVEL) * (i-savei) / decayLength);
            // NSLog(@" ...Denv[%d] %f",i,sEnvs[which][i]);
		}

	//Add token sustain chunk....
	savei = i;
	for (  i = savei; i < savei + sustainLength; i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = SUSTAIN_LEVEL;
            //NSLog(@" ...Senv[%d] %f",i,sEnvs[which][i]);
		}
	savei = i;
	envsave = sEnvs[which][i-1]; //save last env level...
	for (int i = savei; i < savei + releaseLength; i++)
		{
            if (i > sElen[which]) break;   //OUCH! Shouldn't happen
            sEnvs[which][i] = envsave - envsave*((float)(i-savei) / releaseLength);
            //NSLog(@" ...Renv[%d] %f",i,sEnvs[which][i]);
		}
	//DHS WHY doesn't i already have the length here...???
	envDataLength[which] = i + releaseLength;
}  //end buildEnvelope


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//DHS: We need a cleanup here so voices that may be playing don't
//    keep trying play if their buffer gets clobbered!!!
-(void) cleanupNotes:(int)which
{
    int loop;
    LOOPIT(MAX_TONE_EVENTS)
    {
        if (tones[loop].waveNum == which) //gotta kill some tones!
        {
            tones[loop].state   = STATE_INACTIVE;
            tones[loop].waveNum = -1;
            if (midion) OMEndNote((ItemCount)1, tones[loop].midiNote);
            [self decrVoiceCount:loop];
            
        }
    }
}   //end cleanupNotes


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// attempts to fit an algorithmically generated note into a
//   musical key recognizable to human ears....
- (int)makeSureNoteisInKey: (int) wkey : (int) note
{   // 64 is middle C..... so base C is 4, plus five octaves...
    #define NOTEBASE 4
    int result;
	int tloc = 12*wkey + (note-NOTEBASE) % 12;  // C...B range (0-11)
	int octave = (note-NOTEBASE)/12;    
    //NSLog(@" inkey %d %d",wkey,note);
	if (wkey > 11)   return note;  //out of whack? Just return original note.
	if (tloc < 0)    return note;  //June 2013
	if (tloc > 143)  return note;  //June 2013
    result = NOTEBASE + 12*octave + keysiglookups[tloc]; // 'inkey val'
    //NSLog(@" ....result (%d %d) %d",octave,tloc,result);
	return result;
} //end makeSureNoteisInKey



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 1/19 .... add note queue for quantizing....
//   Loop through the queue, and play all notes therein... 
- (void)emptyQueue  
{
    int loop,a,b,c;
    if (!queuePtr) return;
    //NSLog(@"  emptyq, size  %d",queuePtr);
    //if (queuePtr > 250) 
    //    NSLog(@" warning:biggg queueptr: %d",queuePtr);
    LOOPIT(queuePtr)
    {
        a         = noteQueue[0][loop];
        b         = noteQueue[1][loop];
        c         = noteQueue[2][loop];
        gain      = noteQueue[3][loop];
        mono      = noteQueue[4][loop];
        glpan     = noteQueue[5][loop];
        grpan     = noteQueue[6][loop];
        gporto    = noteQueue[7][loop];
        gportlast = noteQueue[8][loop];
        //newUnique = noteQueue[9][loop];

        [self playNote:a:b:c];
    }
    queuePtr = 0; //OK! Queue is empty...    
} //end emptyQueue


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 1/19  .... add note queue for quantizing....
- (void)queueNote:(int)midiNote :(int)wnum :(int)type
{
     //   NSLog(@"  qn %d %d g %f",wnum,type,gain);
    //OK! add our 3 params to the queue...
#if 1 //Shut this off if queue is bad...
    if (queuePtr < MAX_QUEUE-1)
    {
        noteQueue[0][queuePtr] = midiNote;
        noteQueue[1][queuePtr] = wnum;
        noteQueue[2][queuePtr] = type;
        noteQueue[3][queuePtr] = gain;
        noteQueue[4][queuePtr] = mono;
        noteQueue[5][queuePtr] = glpan;
        noteQueue[6][queuePtr] = grpan;
        noteQueue[7][queuePtr] = gporto;
        noteQueue[8][queuePtr] = gportlast;
        //noteQueue[9][queuePtr] = newUnique;
        queuePtr++;
    }
#endif    
   // DHS put this back if queue is broken... [self playNote:midiNote:wnum:type];
} //end queueNote


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)resetArp
{
    arpPtr  = arpPlayPtr = 0;
    arpTime = CACurrentMediaTime();
}



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 3-16-15: Used to create arpeggiated sequences...
//   the arpQueue is a circular queue!
- (void)playNoteWithDelay : (int) midiNote : (int) wnum : (int) type : (int) delayms
{
    
    if (arpPtr == MAX_ARP-1) //Wraparound!
        arpPtr = 0;
    arpQueue[ARP_PARAM_NOTE][arpPtr] = midiNote;  //Similar to note queue but with timers...
    arpQueue[ARP_PARAM_WNUM][arpPtr] = wnum;
    arpQueue[ARP_PARAM_TYPE][arpPtr] = type;
    arpQueue[ARP_PARAM_GAIN][arpPtr] = gain;
    arpQueue[ARP_PARAM_MONO][arpPtr] = mono;
    arpQueue[ARP_PARAM_LPAN][arpPtr] = glpan;
    arpQueue[ARP_PARAM_RPAN][arpPtr] = grpan;
    arpQueue[ARP_PARAM_TIME][arpPtr] = delayms;
    arpPtr++;

} //end playNoteWithDelay



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11-9 need to change to support mono synth...
- (void)playNote:(int)midiNote :(int)wnum :(int)type
{
    int n,foundit=0;
    newUnique++;
    //struct timeval tv;
    //static long oldm=0L;
    //long deltat=0L;
    //long microseconds = 0L;
    //if(gettimeofday(&tv, NULL) == 0)
    //{
    //    microseconds = 1000000*tv.tv_sec + tv.tv_usec ;
    //    deltat = microseconds - oldm;
        //NSLog(@"pn %d [%ld] d[%ld] ",midiNote,microseconds,deltat);
    //    oldm = microseconds;
    //}
    //NSLog(@"...play note %d, type %d, buf %d blen %d dt %d",
    //                  midiNote,type,wnum,sBufLens[wnum],detune);
	if (sBufLens[wnum] <= 0) return;
    // 8/25: Tightened legal note range
    if (midiNote < 8 || midiNote > 127) return;
    //uniqueVoiceCounter++;  //keep track of nth voice...
    if (mono) //ok mono means find old voice and stop it!
    {   //hopefully this will find the correct voice.  
        // if it doesn't work, we need UNIQUE voice ids! UGH!
        // this could fail if we have TWO voices at the same
        //  time w/ same patch and both are mono....???
        for (int n = 0; n < MAX_TONE_EVENTS; ++n)
            if ( tones[n].mono && tones[n].waveNum == wnum  )
//                if ( tones[n].mono && tones[n].waveNum == wnum &&  tones[n].un == newUnique)
            {
                //NSLog(@"  tone n %d wn %d un %d",n,tones[n].waveNum,tones[n].un);
                //Ideally each tone could be put into 'release' state and 
                //  then quietly die down (quickly too)??
                tones[n].state = STATE_MONOFADEOUT;
                if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            }
    }
    foundit = -1;
	for (n = 0; n < MAX_TONE_EVENTS; ++n)
	{ 	if (tones[n].state == STATE_INACTIVE)  // find an empty slot
        {
            foundit = n; 
            break;
        }
    }
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n].toneType = type;
        tones[n].state    = STATE_PRESSED;
        tones[n].midiNote = midiNote;
        tones[n].phase    = 0.0f; 
        tones[n].pitch    = pitches[midiNote];
        //NSLog(@".. note %d ,pitch %f   ",midiNote, pitches[midiNote]);
        [self incrVoiceCount:n];
        if (1 || type == SAMPLE_VOICE)
        { if (detune)
            tones[n].phase    = (int)((float)SAMPLE_OFFSET * 0.005 * (float)sBufLens[wnum]); //compute offset
        }
        tones[n].envStep  = 0.0f;
        tones[n].envDelta = midiNote / 64.0f;
        tones[n].waveNum  = wnum;	
        tones[n].toneType = type;	
        tones[n].gain	  = gain * finalMixGain;
        tones[n].detune	  = detune;
        tones[n].mono 	  = mono;
        tones[n].lpan     = glpan;	 //see setPan!
        tones[n].rpan     = grpan;	 //see setPan!	
        tones[n].portval  = 0;
        tones[n].timetrax = timetrax;
        tones[n].infinite = 0;
        if (type == SYNTH_VOICE)
        {
            tones[n].infinite = infinite;
        }
        tones[n].un       = newUnique;

        // DUH! we need to know WHICH synth voice to track during portamento!?!?!
        //if (gporto) //use portamento?  
        //{
        //    tones[n].portcount  = 20;  
        //    tones[n].portstep = (1.0/(float)tones[n].portcount) * 
        //        (tones[n].pitch - pitches[gportlast]) ; //port step val...
        //     NSLog(@" use port: gportlast %d oldpitch %f newpitch %f step %f",
        //     gportlast,pitches[gportlast],tones[n].pitch,tones[n].portstep);
        //      set to zero here to disable portamento
        //    tones[n].portstep= 0.0;
        //    tones[n].portval  = pitches[gportlast];  
        //  NSLog(@" playport note %d gpl %d pstep %f",
        //      midiNote,gportlast,tones[n].portstep);            
        //}
        //else
        //    tones[n].portstep = 999999; //NO portamento
        //tones[n].un = uniqueVoiceCounter; //save this in the tone
        //NSLog(@"  ...got played %d, wnum %d gain %f, fmg %f",midiNote,wnum,gain,finalMixGain);
        if (midion)  //Send out MIDI...
        {
            int vel = (int)(444*gain);
            if (vel > 127) vel = 127;
            OMSetDevice(midiDev);
            OMPlayNote(midiChan, midiNote, vel );   
        }
    
    }
        
    //if (foundit == -1) NSLog(@" ...ran out of tone space! limit=%d",MAX_TONE_EVENTS);
} //end playNote


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// This plays a SYNTH note with a custom pitch: NO NOTES USED!
// Not considered a "voice" so it doesn't increment voice count...
//  Wnum should be 0-7???
//  pitch is floating point, in HZ
- (void)playPitchedNote:(float)pitch :(int)wnum
{
    int n,foundit=0;
    newUnique++;
    if (sBufLens[wnum] <= 0) return;
    foundit = -1;
    for (n = 0; n < MAX_TONE_EVENTS; n++)
	{
        if (tones[n].state == STATE_INACTIVE)  // find an empty slot
          {foundit = n;
           break;
          }
    }
    //if (1) NSLog(@"... playPitchedNote  Pitch %f, buf %d blen %d tone %d founditbin %d", pitch,wnum,sBufLens[wnum],n,foundit);
    if (foundit != -1)  //empty slot? Play that note!
    {
        n=foundit;
        tones[n].toneType = SYNTH_VOICE;
        tones[n].state    = STATE_PRESSED;
        // NO NOTE!  tones[n].midiNote = midiNote;
        tones[n].phase    = 0.0f;
        tones[n].pitch    = pitch;
        [self incrVoiceCount:n];
        tones[n].envStep    = 0.0f;
        tones[n].envDelta   = 1.0f;  //This needs to be canned!!! Maybe NO envelope?
        tones[n].waveNum  = wnum;
        tones[n].gain	          = gain * finalMixGain;
        tones[n].detune	= 1;
        tones[n].mono 	= 0;  //Since we cannot find this easily, force polyphony for now
        tones[n].lpan          = glpan;	 //see setPan!
        tones[n].rpan          = grpan;	 //see setPan!
        tones[n].portval      = 0;
        tones[n].timetrax    = timetrax;
        tones[n].un             = newUnique;
        
    }
    
    //if (foundit == -1) NSLog(@" ...ran out of tone space! limit=%d",MAX_TONE_EVENTS);
} //end playPitchedNote

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Designed to be used with pitched note: release note by actual wave BIN
- (void)releaseNoteByBin:(int)n
{
    tones[n].state   = STATE_INACTIVE;
    tones[n].waveNum = -1;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Aug 26: OK I want this to KLOBBER ALL audio output!
- (void)releaseAllNotes  
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
        [self releaseNoteByBin:n];
        if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
	}
    numSVoices = numPVoices = 0;
} //end releaseAllNotes

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// This happens if user kills a voice??? Doesn't work too good,
//   since the audio queue is already been fed out..... still get delayed result
- (void)releaseAllNotesByWaveNum:(int)wn  
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
	//	NSLog(@" releaseAll... n %d wn%d vs %d",n,tones[n].waveNum);
	  if (tones[n].waveNum  == wn)
      {
          [self releaseNoteByBin:n];
          if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
          [self decrVoiceCount:n];
      }
	}

}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
//DHS 12-1: Added check to make sure both NOTE and wave num match before
//  forcing release in MONO mode...
- (void)releaseNote:(int)midiNote :(int)wnum
{
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].midiNote == midiNote && 
            tones[n].waveNum == wnum &&	
            tones[n].state != STATE_INACTIVE)
		{
			tones[n].state = STATE_RELEASED;
            //Is this the best place for this?
            if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
            [self decrVoiceCount:n];
			// We don't exit the loop here, because the same MIDI note may be
			// playing more than once, and we need to stop them all.
		}
	}
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
-(NSString *)getAudioOutputFileName
{
    return recFileName;   
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getSVoiceCount 
{
    return numSVoices;
    
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getNeedToMailAudioFile 
{
    return needToMailAudioFile;
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setNeedToMailAudioFile:(int)n
{
    needToMailAudioFile=n;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DANGEROUS: makes note play FOREVER!
- (void)setInfinite:(int)n
{
    infinite=n;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getPVoiceCount 
{
    return numPVoices;
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)incrVoiceCount:(int)n
{
    // NSLog(@" ..INCR voice count(%2.2d),note %3.3d, (%2.2d %2.2d)",
    //        n,tones[n].midiNote, numSVoices,numPVoices);
    if (tones[n].toneType == SYNTH_VOICE || tones[n].toneType == SAMPLE_VOICE)
    { // NSLog(@" ...incr SYNTH");
        numSVoices++;
    }
    else 
    {
        //NSLog(@" ...incr PERC");
        numPVoices++;
    }
   //NSLog(@" ..DONEINCR %d sv   %d pv",numSVoices,numPVoices);

} //end incrVoiceCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)decrVoiceCount:(int)n
{
    // NSLog(@" ..DECR voice count(%2.2d),note %3.3d, (%2.2d %2.2d)",
    //        n,tones[n].midiNote, numSVoices,numPVoices);
    if (tones[n].toneType == SYNTH_VOICE || tones[n].toneType == SAMPLE_VOICE)
    {
        numSVoices--;
        if (numSVoices < 0) numSVoices = 0;
    }
    else 
    {
        numPVoices--;
        if (numPVoices < 0) numPVoices = 0;
    }
    //NSLog(@" ..DONEDECR %d sv   %d pv",numSVoices,numPVoices);
} //end decrVoiceCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// DHS 11/29: Used to clear out stray sounds if user quits a game early?
- (int)clearBuffer:(void*)buffer frames:(int)frames
{
	SInt16* p = (SInt16*)buffer;
    int f;
    for (f = 0; f < frames; ++f)
    {
		p[f*2]     = 0;     //LEFT
        p[f*2 + 1] = 0;   //RIGHT
    }
    return 0;
} //end clearBuffer

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// THIS NEEDS TO BE TIGHT AS POSSIBLE!!!!
- (int)fillBuffer:(void*)buffer frames:(int)frames
{
	SInt16* p = (SInt16*)buffer;
	int f,n,a,c,wn;
    int sbc;
	float sValue,sValue2,ml,mr,b,sl,sr,envValue; 
	//double startTime = CACurrentMediaTime();
    sValue = sValue2 = 0.0f; //DHS 7/10/15 Compiler warnings
	// We are going to render the frames one-by-one. For each frame, we loop
	// through all of the active ToneEvents and move them forward a single step
	// in the simulation. We calculate each ToneEvent's individual output and
	// add it to a mix value. Then we write that mix value into the buffer and 
	// repeat this process for the next frame.
	for (f = 0; f < frames; ++f)
	{
		ml = mr = 0.0f;  // the mixed value for this frame
		for (n = 0; n < MAX_TONE_EVENTS; ++n)
		{
			if (tones[n].state == STATE_MONOFADEOUT)  // fading out in mono mode?
            {
                tones[n].gain *= 0.5; //attenuate gain by half each sample (TUNE IF NEEDED)...
                if (tones[n].gain < 0.09)  //volume below 10%? Outtahere!
                  
                {
                    //NSLog(@" tone %d fadeout",n);
                    tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
                    [self decrVoiceCount:n];
                 }

            }
            if (tones[n].state == STATE_INACTIVE)  // only active tones
                   continue;    //this is krude! but it bypasses logic below and goes to end of loop
			wn = tones[n].waveNum ;
			// The envelope is precomputed and stored in a look-up table.
			// For MIDI note 64 we step through this table one sample at a
			// time but for other notes the "envStep" may be fractional.
			// We must perform an interpolation to find the envelope value
			// for the current step. 
            if (tones[n].toneType == SYNTH_VOICE ) //0 - 7: synths...we need an envelope
			{
                if (tones[n].infinite) envValue = 1.0;
                else
                {
                    a = (int)tones[n].envStep;   // integer part
                    b = tones[n].envStep - a;  // decimal part
                    c = a + 1;
                    if (c >= envLength[wn])  // don't wrap around
                        c = a;
                    //NSLog(@"wnum %d krashit! a/b/c is %d/%f/%d elen %d",
                    //      wn,a,b,c,envLength[wn]);
                    if (c > sElen[wn])
                        //illegal envelope access!
                    {
                        //if (0) NSLog(@"Illegal Envelope access: eLen[%d] = %d, abc %d %d %d",wn,sElen[wn],a,b,c);
                        //c = 0;
                        envValue = 0.0;
                    }
                    else if (sEnvs[wn] != NULL) //DHS nov 27 add existance check for sEnvs
                        envValue = (1.0f - b)*sEnvs[wn][a] + b*sEnvs[wn][c];
                    else {
                        envValue = 0.0;
                    }
                    // Get the next envelope value. If there are no more values,
                    // then this tone is done ringing.
                    tones[n].envStep += tones[n].envDelta;
                    if (((int)tones[n].envStep) >= envDataLength[wn]  )
                    {
                        tones[n].state   = STATE_INACTIVE;
                        tones[n].waveNum = -1;
                        if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
                        [self decrVoiceCount:n];
                        continue;
                    }
                   
                }
			}  //end synth/sample voice
			else  //Percussion/Sample voice? We won't apply envelope
				envValue = 1.0;
			// The steps in the sine table are 1 Hz apart, but the pitch of
			// the tone (which is the value by which we step through the
			// table) may have a fractional value and fall in between two
			// table entries. We will perform a simple interpolation to get
			// the best possible sine value.
			a = (int)tones[n].phase;  // integer part
			b = tones[n].phase - a;   // decimal part
			c = a + 1;
			sbc = sBufChans[wn];
			if (wn < 8) //0 - 7: synths...
			{
				while (a >= sineLength) a -= sineLength;  // wrap a and c ptrs
				while (c >= sineLength) c -= sineLength;  					
			}
			else  //percussion/sample waves...
			{
				if (a >= sBufLens[wn])
				{ 	a = sBufLens[wn]-1; // sample: nowrap!
					c = a;
				}
			}
//            sValue = 0;
//			if (sbc == 1) //mono...
//				sValue = (1.0f - b)*sBufs[wn][a] + b*sBufs[wn][c];
//			else if (sbc == 2) //stereo...
//			{
//				sValue  = (1.0f - b)*sBufs[wn][2*a] + b*sBufs[wn][2*c];
//				sValue2 = (1.0f - b)*sBufs[wn][1+2*a] + b*sBufs[wn][1+2*c];
//			}
			// Wrap round when we get to the end of the sine look-up table.
			if (tones[n].toneType == SYNTH_VOICE) //0 - 7: synths...
			{
                tones[n].phase += tones[n].pitch;
 				if (((int)tones[n].phase) >= sineLength)
					tones[n].phase -= sineLength;
				if (((int)tones[n].phase) < 0 )
					tones[n].phase += sineLength;
                //if (n == 1) NSLog(@" ... sval %f",sValue);
			}
			//DHS general sampling will have a pitch associated with it!
			else if (tones[n].toneType == SAMPLE_VOICE) //samples ! but not perc!
			{
				//DHS: this coeff gets us close to the initial sample's pitch
				//    when C4 is pressed on the keyboard....
				if (tones[n].detune)  //Detune? use pitch to step thru...
					tones[n].phase += 0.0029*(tones[n].pitch);
				else 
					tones[n].phase++; //NO detune. step thru by onesies...
				if (((int)tones[n].phase*sbc) >= sBufLens[wn]-2) //End sample/tone! DHS 6/6/17 add -1
//WTF???                    if (((int)tones[n].phase*2) >= sBufLens[wn]) //End sample/tone!
				{
                    //NSLog(@" ..end tone %d,%d, blen %d",n,wn,sBufLens[wn]);
					tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
					tones[n].phase = 0;
                    [self decrVoiceCount:n];
				}
			}
			else   //percussion samples: NO PITCH
			{   
 				if (tones[n].detune) //tones[n].midiNote != 64)  //Octave shift in percussion??? SHIFTIT!
					tones[n].phase += 0.0029*(tones[n].pitch);
				else 
                    tones[n].phase++; //no octave: step thru by onesies...
                //DHS FOR some reason, percs > 8 NEVER GET HERE!

				if (((int)tones[n].phase*sbc) >= sBufLens[wn]) //End sample/tone!
                if (((int)tones[n].phase*2) >= sBufLens[wn]) //End sample/tone!
				{
					tones[n].state   = STATE_INACTIVE;
                    tones[n].waveNum = -1;
                    if (midion) OMEndNote((ItemCount)1, tones[n].midiNote);
					tones[n].phase = 0;
                    //NSLog(@" decr 4 n %d, dt %d",n,tones[n].detune);
                    [self decrVoiceCount:n];
				}
			}
            if (tones[n].state != STATE_INACTIVE) //DHS 6/6/17
            {
                sValue = 0;
                if (sbc == 1) //mono...
                    sValue = (1.0f - b)*sBufs[wn][a] + b*sBufs[wn][c];
                else if (sbc == 2) //stereo...
                {
                    sValue  = (1.0f - b)*sBufs[wn][2*a] + b*sBufs[wn][2*c];
                    sValue2 = (1.0f - b)*sBufs[wn][1+2*a] + b*sBufs[wn][1+2*c];
                }
                
                // Calculate the final sample value.
                //  we need to fill Left/Right buffers EVEN with mono samples!
                sl = sValue * envValue * tones[n].gain  * tones[n].lpan;
                // NSLog(@" sl: %f %f %f %f",sValue,envValue,tones[n].gain,tones[n].lpan);
                sr = 0;
                if (sbc == 1) //mono...
                    sr = sValue * envValue * tones[n].gain  * tones[n].rpan;
                else if (sbc == 2) //stereo...
                    sr = sValue2 * envValue * tones[n].gain  * tones[n].rpan;
                // Add it to the mix.
                ml += sl;
                mr += sr;
            }
		} //end n loop; done mixing tones
		//NSLog(@" 1mlr %f %f",ml,mr);
        //DHS masterlevel is new as of 2013: Try ultra boost 2.0...
        ml*=(masterLevel);
        mr*=(masterLevel);
		// Clamp MIX to make sure it is within the [-1.0f, 1.0f] range.
		if (mr > 1.0f)       mr = 1.0f;
		else if (mr < -1.0f) mr = -1.0f;
		if (ml > 1.0f)       ml = 1.0f;
		else if (ml < -1.0f) ml = -1.0f;
        
		// Write the sample mix to the buffer as TWO 16-bit words.
		p[f*2]     = (SInt16)((ml ) * 0x7FFF);     //LEFT 
		p[f*2 + 1] = (SInt16)((mr ) * 0x7FFF);   //RIGHT
        //if (f < 256) NSLog(@" 2mlr %f %f p %d/%x %d/%x",ml,mr,p[f*2],p[f*2],p[f*2+1],p[f*2+1]);
        //DHS feb 2013: Store latest audio output in a volume buffer...
        lrvolmod++;
        //take sample every 8 frames...
        if (lrvolmod % 8 == 0)
        {
            lvolbuf[lrvolptr]=ml;
            rvolbuf[lrvolptr]=mr;
            lrvolptr++;
            if (lrvolptr > 15) lrvolptr=0; //wrap around...
        }
	
    } //end insane main loop...
    //OK at this point we have a valid buffer; recording?
//    if (0 && recording)
//    {  int loop,rindex,rsize= f*2 + 1; //number of floats in our buffer...
//        short sval;
//        SInt16 si6;
//        rindex = recptr;
//        LOOPIT(2*frames)
//        {   si6 = (p[loop]);
//            sval = (short) si6;
//            //if (0 && rindex < 256)
//            //    NSLog(@" [%d] pakaudio px %x  si6 %d/%x s %d / %x",
//            //              rindex,p[loop],si6,si6,sval,sval);
//             audioRecBuffer[rindex] = sval;
//            rindex++;
//        }
//        //NSLog(@" ..wrbuf %d",recptr);
//        recptr+=(rsize-1);    //advance ptr
//        if (recptr >= recsize/2)  //DHS why /4?  hmmm why /2?
//        {
//            //NSLog(@" ...bing stop");
//            [self stopRecording:0];
//        }
//    } //end if recording
	//NSLog(@"elapsed %g", CACurrentMediaTime() - startTime);

	return frames;
} //end fillBuffer

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setGain: (int)newGainInt 
{
	//we get a new gain value from 0 to 255, and set our gain accordingly,
	//  ranging from 0 to 1
	gain = (float)newGainInt/255.0;
}//end setGain

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setUnique: (int)newUniqueInt 
{
	//we get a new gain value from 0 to 255, and set our gain accordingly,
	//  ranging from 0 to 1
	newUnique = newUniqueInt;
}//end setGain

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getMidiOn   
{
	return midion;
}//end getMidiOn



//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setMidiOn: (int)onoff 
{
    //NSLog(@" ...synth set MIDI on/off %d",onoff); 
	midion = onoff;
}//end setMidiOn

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setMIDI: (int)mdev :(int)mchan
{
	//we get a new gain value from 0 to 255, and set our gain accordingly,
	//  ranging from 0 to 1
	midiDev  = mdev;
	midiChan = mchan;
}//end setMIDI

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setTimetrax:(int)newVal 
{
	//this is off/on for now, 0 , 1
	timetrax = newVal;
}//end setGain


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// used to match old voice's unique lil track (to clobber last mono note)
- (void)setMonoUN: (int)un 
{
    monoLastUnique = un;
}//end setMonoUN


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets up portamento for a voice, 0 = none, 1 = some (fixed amount for now)
- (void)setPortamento: (int)pn 
{
    //NSLog(@" set port %d",pn);
    gporto = (float)pn;
}//end setPortamento

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sets up portamento for a voice, 0 = none, 1 = some (fixed amount for now)
- (void)setPortLast: (int)lastnote 
{
    gportlast = lastnote;
}//end setPortamento


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// Sets globals lpan and rpan, stored w/ tones in playnote.
- (void)setPan: (int)newPanInt 
{
	float dogf;
	dogf = (float)newPanInt;
	//NSLog(@" setpan %d %f",newPanInt,dogf);
	grpan = dogf/255.0;
	glpan = 1.0 - dogf/255.0;
	
} //end setPan

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getLVolume 
{
    int loop;
    float r=0;
    LOOPIT(16)r+=ABS(lvolbuf[loop]);
    r/=16.0;
    return r;
} //end getLVolume

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getRVolume 
{
    int loop;
    float r=0;
    LOOPIT(16)r+=ABS(rvolbuf[loop]);
    r/=16.0;
    return r;
} //end getRVolume

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getUniqueCount 
{
    return(uniqueVoiceCounter);
}  //end getUniqueCount

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getNoteCount 
{   int nc=0;
	for (int n = 0; n < MAX_TONE_EVENTS; ++n)
	{
		if (tones[n].state != STATE_INACTIVE)  // only active tones
			nc++;
	}
	return nc ;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (float)getADSR: (int)which : (int)where 
{
	// if (where % 32 == 0) NSLog(@" getADSR %d  %d ",which,where);
	if (!envIsUp[which]) return -1.0;
	if (where >= envLength[which]) return -2.0;
	return sEnvs[which][where];
}
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (int)getEnvDataLen:(int)which  
{
	if (!envIsUp[which]) return 0.0;
	return envDataLength[which];
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setAttack: (int)newVal 
{
 	//take our percent val, turn it into our attack val (0 - .1)!!!
 	ATTACK_TIME = (float) newVal/SYNTH_TS;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDecay: (int)newVal 
{
 	//take our percent val, turn it into our decay val (0 - .1)!!!
 	DECAY_TIME = (float) newVal/SYNTH_TS;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSustain: (int)newVal 
{
 	//take our percent val, turn it into our sustain val (0 - .1)!!!
 	SUSTAIN_TIME = 5.0 * (float) newVal/SYNTH_TS;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSustainL: (int)newVal 
{
 	//take our percent val, turn it into our sustain level (DIFFERENT: 0 - 1)!!!
 	SUSTAIN_LEVEL = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setRelease: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	RELEASE_TIME = (float) newVal/SYNTH_TS;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDuty: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	DUTY_TIME = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setSampOffset: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	SAMPLE_OFFSET = (float) newVal/100.0;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setDetune: (int)newVal 
{
 	//take our percent val, turn it into our release val (0 - .1)!!!
 	detune = newVal;
}

//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
- (void)setMono: (int)newVal 
{
 	//on/off here...
 	mono = newVal;
}


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// sept 7: WRITE WAV FILE?????
// Sept 11: OK. This is yielding error 1718449215 (hex  666d743f) or "fmt?"
//          which is kAudioFileUnsupportedDataFormatError
//          Same err trying WAV or AIFF file, ok kAudioFormatULaw seems OK!
// Currently ignores input name strings....
//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==-----
//objc[876]: Object 0x1f59d550 of class __NSCFString autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f5a3290 of class NSPathStore2 autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f59c690 of class __NSCFString autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
//objc[876]: Object 0x1f5af400 of class NSPathStore2 autoreleased with no pool in place - just leaking - break on objc_autoreleaseNoPool() to debug
- (void)writeOutputSampleFile:(NSString *)name :(NSString *)type
{ 	 
    UInt32 bytesize,packetsize;
    int err;
    char errc[8];
	AudioFileID fileID = nil;
	AudioStreamBasicDescription outFormat;

 	recFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:@"oogieAudioDump.caf"];
    //NSLog(@" in dumpAudio...name %@",recFileName);
 	outFormat.mSampleRate		= 11025; 
	outFormat.mFormatID			= kAudioFormatLinearPCM;  
    outFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger;
    outFormat.mFramesPerPacket	= 1;  //single frame, nothing fancy
    outFormat.mChannelsPerFrame	= 2;  //stereo
    outFormat.mBytesPerFrame	= 4;  //two shorts
    outFormat.mBytesPerPacket	= 4;  //again, two shorts
    outFormat.mBitsPerChannel   = 16; // deep audio
    //DHS 7/19/13. recptr is in WORDS, so add 2x
    bytesize = 2*recptr;
    packetsize = bytesize/outFormat.mBytesPerPacket;
    //if (0) NSLog(@" dump audio inside recorder... bs %d bpp %d ps %d",
    //      bytesize,outFormat.mBytesPerPacket,packetsize); 
    NSURL* recURL = [NSURL URLWithString:recFileName];
    //NSLog(@" dump %d bytes audio to url:%@",bytesize,url);
    err = AudioFileCreateWithURL( (__bridge CFURLRef)recURL,
                                 kAudioFileCAFType,
                                 &outFormat, 
                                 kAudioFileFlags_EraseFile, 
                                 &fileID);
    
    
    if (err) memcpy(errc,&err,4);
    //if (err) NSLog(@" error on AudioFileCreateWithURL , code %d %s",err,errc);
    err=AudioFileWritePackets (	fileID,  
                               FALSE,
                               bytesize,   // byte size?
                               NULL ,
                               0,           // start at zero packets...
                               &packetsize,  //# packets
                               audioRecBuffer);	
    
    if (err) memcpy(errc,&err,4);
    //if (err) NSLog(@" error on AudioFileWritePackets , code %d %s",err,errc);
    //NSLog(@" ...writeOutputSampleFile err %d, %d bytes",err,(int)bytesize);
	AudioFileClose(fileID);
    if (!err) needToMailAudioFile=1;
} //end writeOutputSampleFile


//------==(SYNTHDAVE)==---------==(SYNTHDAVE)==---------==(SYNTHDAVE)==------
// 4/29/13: Add web support?
// 5/31/13: Add nils to fileid/fileurl, fix possible corruption bug
- (void)loadSample:(NSString *)name :(NSString *)type
{
    AudioFileID fileID; //DHS 11/12
    OSStatus err;
	int sws;
	char duhchar[8];
	UInt32 theSize,outNumBytes,readsize;
	UInt64 packetCount,bCount;
    NSURL *fileURL = nil;
	AudioStreamBasicDescription outFormat;
	UInt32 thePropSize = sizeof(outFormat);
    //NSLog(@" ..sample name %@ type %@",name,type);
    if ([type  isEqual: @"WEB"]) //we're pulling sample down from web?
        {
            //fileURL = [[NSURL alloc] initWithString:name]; //file not found?
            if (name == NULL)
            {   //NSLog(@" ..sample load error 2");
                return;
            }
            fileURL = [[NSURL alloc] initFileURLWithPath: name];  //file not found!
            //NSLog(@" pull webfile %@",name);
        }
    else 
        {
            //NSLog(@" sfpath %@:%@",name,type);
            NSString *soundFilePath  = [[NSBundle mainBundle] pathForResource:name ofType:type];
            if (soundFilePath == NULL)
            {   //NSLog(@" ..sample load error 1");
                return;
            }
           fileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
        }
 	err = AudioFileOpenURL ((__bridge CFURLRef) fileURL, kAudioFileReadPermission,0,&fileID);
    
	if (err)
	{  
       //if (err == kAudioFileFileNotFoundError)
       //    NSLog(@" ..sample file not found err %d",(int)err);
       // else
       //     NSLog(@" ..sample load error %d",(int)err);
		return;
	}
	// NSLog(@"File ID %d %x",fileID,fileID);
	// read size and format
	AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &thePropSize, &outFormat);
	//if (0) NSLog(@"mSampleRate %d mBytesPerPacket %d chans %d",
    //      (int)outFormat.mSampleRate,(int)outFormat.mBytesPerPacket,outFormat.mChannelsPerFrame);
	theSize = outFormat.mFormatID;
	memcpy(duhchar,&theSize,4);
	//NSLog(@" ...format str %s",duhchar);
	// if (outFormat.mFormatID == kAudioFormatMPEG4AAC)  NSLog(@" ..found mp4 format..");
	// if (outFormat.mFormatID == kAudioFormatLinearPCM) NSLog(@" ..found linear PCM format..");
	sChans = outFormat.mChannelsPerFrame;
	theSize = sizeof(packetCount);
	err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount,
							   &theSize, &packetCount);	
	//errnum = 0;
	//if (err) errnum = 1;
    bCount = 0;
	theSize = sizeof(bCount);
	if (!err) err = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataByteCount,
							   &theSize, &bCount);
	//if (err) errnum = 2;
	//if (err) NSLog(@" LoadSample Err:%d",(int)err);
	sPacketSize = (int)bCount;
	sNumPackets = (int)packetCount;
	//NSLog(@" loadSample: sNumPackets %d   sChans %d bcount %d max %d",sNumPackets, sChans,bCount,MAX_SAMPLE_SIZE);
    //DHS we have to tell caller about this!!!
	if (bCount > MAX_SAMPLE_SIZE) 
	{
         gotSample = 0;
		 //NSLog(@"Sample file too big! (over %d)  %d",MAX_SAMPLE_SIZE,(int)bCount);
		 return;	
	}
	// freeup old swave is needed
	if (swave != NULL) 
	{
        //NSLog(@"  Free swave " );
		free(swave);
		swave = NULL;
	}
	//OK, short data!
    //NSLog(@"  Malloc swave, size %d chans %d",sNumPackets,sChans);
    sws = sNumPackets * sChans * sizeof(short);
	swave = (unsigned short *)malloc(sws);
    if (swave == NULL) //ERROR! Swave failed!
    {
        swaveSize = 0;
        //NSLog(@"Swave alloc failed (%d bytes) ",sws);
        return;	
    }
    else
    {
        swaveSize = sNumPackets * sChans;
    }
	readsize = sNumPackets * sChans;
    
    if (!err) err = AudioFileReadPacketData(fileID, FALSE, &outNumBytes, NULL, 0, &readsize, swave);
    
	//DHS 11/12 if (!err)err = AudioFileReadPackets (fileID,FALSE,&outNumBytes,NULL,0,&readsize,swave);
	sampleSize =  readsize; 	
	//if(0) LOOPIT(sampleSize)
	//{   duh1 = (int)swave[loop];
	//	 if (loop % 128 == 0) 
	//	       NSLog(@" ...ap[%d] %d %x",loop,duh1,swave[loop]);
	//}

	if (!err)  AudioFileClose(fileID);
    gotSample = 1;
    //if (err != 0) NSLog(@" loadsample error: %d",(int)err);
    //else NSLog(@" ...load sample OK");
	return;
	
} //end loadSample




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
