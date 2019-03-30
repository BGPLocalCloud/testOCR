//
//                             _ _______  __
//   ___  ___  _   _ _ __   __| |  ___\ \/ /
//  / __|/ _ \| | | | '_ \ / _` | |_   \  /
//  \__ \ (_) | |_| | | | | (_| |  _|  /  \
//  |___/\___/ \__,_|_| |_|\__,_|_|   /_/\_\
//
//
//  soundFX: encapsulates synth and audio buffer objects...
//  Created by dave scruton on 3/2/16
//  Copyright (C) fractallonomy, Inc. All rights reserved.
//
// DHS 3/10      Add loadAudioBKGD call from sfx
// DHS 3/12      Add start/stop
// DHS 11/19     Add pitch/level/pan sound method
// To test for memory corruption, choose "Edit Scheme"
//   (choose pix in the pix > Dave's iphone window, edit scheme)
//   Look for "Memory Management"  and enable Guard Malloc
// DHS 6/3/18   add hueToNote, redo glintmusic
#include "soundFX.h"

@implementation soundFX

@synthesize delegate = _delegate;

double drand(double lo_range,double hi_range );

static soundFX *sharedInstance = nil;

// DHS 1/14/15  static int audioClickCount = 0; //DEBUG
//New Glint Rewards: Use color to get a note...
int HH,LL,SS;  //Used in rgb -> HLS
#define  HLSMAX   255   // H,L, and S vary over 0-HLSMAX
#define  RGBMAX   255   // R,G, and B vary over 0-RGBMAX

//=====(soundFX)======================================================================
// Get the shared instance and create it if necessary.
+ (soundFX *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    
    return sharedInstance;
}


//=====(soundFX)======================================================================
-(instancetype) init
{
    if (self = [super init])
    {
        // The Synth and the AudioBufferPlayer must use the same sample rate.
        // Start low if in doubt of CPU... buffersize 800 and samplerate 16k
        //   means buf gets filled in less than .05 secs... else, CRACKLING NOISE
        //sampleRate = 11025.0f; //DHS may 31: this is to match our new .wav samples
        sampleRate = 44100.0f;
        // Create the synthesizer before we create the AudioBufferPlayer, because
        // the AudioBufferPlayer will ask for buffers right away when we start it.
        synth = [[Synth alloc] initWithSampleRate:sampleRate];
        // Create the AudioBufferPlayer, set ourselves as the delegate, and start it.
        //  this stuff gets turned off in dealloc()
        // DHS NOTE: iWSR calls same-named routine in Synth!!!
        player = [[AudioBufferPlayer alloc] initWithSampleRate:sampleRate channels:2 bitsPerChannel:16 packetsPerBuffer:1024];
        player.delegate = self;
        //NOTE: this is WAY LOUDER than the oogiepad version. WHY!?!?!?
        player.gain = 2.0f;
        float oogieMasterLevel = 1.0;
        [synth setMasterLevel:oogieMasterLevel];
        //NSLog(@"Start sampleplayer..." );
        [player start];
        for (int i=0;i<MAX_SOUNDFILES;i++)
        {
            soundFileNames[i]  = @"";
            soundFileLoaded[i] = false;
        }
        _enabled = TRUE;
        
        //Check to see if we are unique?
        _soundRandKey = drand(0.0,100.0);
     }
    return self;
} //end init


//=====(soundFX)==========================================
- (void) start
{
    [player start];
}
//=====(soundFX)==========================================
- (void) stop
{
    [player stop];
}


//=====(soundFX)==========================================
- (void) releaseAllNotesByWaveNum : (int) which
{
    [synth releaseAllNotesByWaveNum:which];
} //end releaseAllNotesByWaveNum

//=====(soundFX)==========================================
- (void) setMasterLevel : (float) level
{
    [synth setMasterLevel : level];
}


//=====(soundFX)==========================================
- (void) setPan : (int) pan
{
    [synth setPan:pan];
} //end setPan

//=====(soundFX)==========================================
-(void) setSoundFileName : (int) index : (NSString *)sfname
{
    if (index < 0) return;
    if (index >= MAX_SOUNDFILES) return;
    soundFileNames[index] = sfname;
    index++; //Use for count value
    if (index > soundFileCount) soundFileCount = index;
} //end setSoundFileName


//=====(soundFX)==========================================
- (void) setPuzzleColor : (int) index : (UIColor *)color
{
    if (index < 0) return;
    if (index >= 36) return;
    puzzleColors[index] = color;
    
}

//=====(soundFX)==========================================
-(void) swapPuzzleColors : (int) pfrom : (int) pto
{
    UIColor *wcolor = puzzleColors[pfrom];
    puzzleColors[pfrom] = puzzleColors[pto];
    puzzleColors[pto]   = wcolor;
}

//======(Hue-Do-Ku)==========================================
// NOTE: this cannot send out midi events!!!
//   quick basic tick sound...
- (void) makeTicSound:(int)which
{
    int note = 64;
    if (!_enabled || !soundFileLoaded[which]) return;
 
    //NSLog(@" tic %d",which);
    if (which == 2)
    {
        note = 96;
        [synth setDetune: 1];
    }
    if (which == 4)
    {
        [synth setDetune: 1];
    }
    [synth setGain:22];
    [synth setPan:128];   // Center pan
    [synth playNote:note:which:SAMPLE_VOICE];
    
} //end makeTicSound


//=====(soundFX)==========================================
// experimental touch music
- (void)makeTicSoundWithXY : (int) which : (int) x : (int) y
{
    
    if (!_enabled || !soundFileLoaded[which]) return;
    //   which = 1;
    //    int note = 12 * (y/10) + x/20;
    int stepper = 1 + (y % 12);
    int note = x + y;
    if (!_enabled) return; //bail on audio off
    [synth setDetune: 1];
    [synth setGain:22];
    [synth setPan:128];   // Center pan
    
    note = stepper *  ( note/stepper);
    
    int inkeynote = [synth makeSureNoteisInKey: KEY_MAJOR : note];
    
    
    [synth playNote:inkeynote:which:SAMPLE_VOICE];
    
} //end makeTicSoundWithXY

//=========(soundFX)========================================================================
-(int) makeSureNoteisInKey : (int) keysig : (int) note
{
    return [synth makeSureNoteisInKey: keysig : note]; //just a handoff
}



//=========(soundFX)========================================================================
- (void)makeTicSoundWithPitchandLevel : (int) which : (int) ppitch : (int) level
{
    int note = ppitch;
    if (!_enabled || !soundFileLoaded[which]) return;
    //NSLog(@" ticpitch %d %d %d",which,ppitch,level);
    [synth setDetune: 1];
    [synth setGain:level];
    [synth setPan:128];   // Center pan
    [synth setMidiOn:0];   //disable midi temporarily
    [synth playNote:note:which:SAMPLE_VOICE];
    
    
} //end makeTicSoundWithPitchandLevel


//=========(soundFX)========================================================================
- (void)makeTicSoundWithPitchandLevelandPan : (int) which : (int) ppitch : (int) level : (int) pan
{
    int note = ppitch;
    if (!_enabled || !soundFileLoaded[which]) return;
    //NSLog(@" ticpitch %d %d %d",which,ppitch,level);
    [synth setDetune: 1];
    [synth setGain:level];
    [synth setPan:pan];   // Center pan
    [synth setMidiOn:0];   //disable midi temporarily
    [synth playNote:note:which:SAMPLE_VOICE];
    
    
} //end makeTicSoundWithPitchandLevel


//=========(soundFX)========================================================================
// NOTE: this cannot send out midi events!!!
//   quick basic tick sound...
- (void) makeTicSoundWithPitch : (int) which : (int) pitch
{
    int note = pitch;
    if (!_enabled || !soundFileLoaded[which]) return;
    [synth setDetune: 1];
    [synth setGain:22];
    [synth setPan:128];   // Center pan
    [synth playNote:note:which:SAMPLE_VOICE];
    
} //end makeTicSoundWithPitch



//=========(soundFX)========================================================================
-(void) loadAudio
{
    //NSLog(@"load Audio...");
    int loop,sampnum = 0; //Loop over samples, skip 6 (already loaded)
    //    for(loop=0;loop<NUM_SAMPLES;loop++)
    for(loop=0;loop<soundFileCount;loop++)
    {
        if (sampnum >= MAX_SAMPLES) break; //DHS aug 2012 fix. was using loop!
        //NSLog(@" ...loadsamp(%d) Name %@",loop,hdkSoundFiles[loop]);
        [synth loadSample:soundFileNames[loop]:@"wav"];
        [synth buildSampleTable:sampnum];
        soundFileLoaded[loop] = true;
        sampnum++;
        //if (loop == 1) [synth dumpAudioBuffer:1 :256];
    }
    
    
} //End loadAudio


//=========(soundFX)========================================================================
// Loads MOST samples in bkgd, but immediate # is loaded
//   right away in the foreground, -1 means no immediate num
-(void) loadAudioBKGD : (int) immediateSampleNum
{
    
    //Load audio samples...
    int sampnum = immediateSampleNum;
    if (sampnum >= 0)  //Got an immediate sample to load?
    {
        // Set this up to preload one sample in foreground... (6 is typical)
        [synth loadSample:soundFileNames[sampnum]:@"wav"];
        [synth buildSampleTable:sampnum];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       dispatch_sync(dispatch_get_main_queue(), ^{
                           int loop,ssampnum = 0; //Loop over samples, skip 6 (already loaded)
                           for(loop=0;loop<self->soundFileCount;loop++)
                           {
                               if (ssampnum >= MAX_SAMPLES) break; //DHS aug 2012 fix. was using loop!
                               //Not preloaded sample?
                               if (loop != immediateSampleNum)
                               {
                                   //SOMEHOW this line makes sample-1-corruption bug go away. WTF??
                                   //NSLog(@"  load audio %d: %@",loop,soundFileNames[loop]);
                                   [self->synth loadSample:self->soundFileNames[loop]:@"wav"];
                                   [self->synth buildSampleTable:ssampnum];
                                   self->soundFileLoaded[loop] = true;
                                   NSLog(@" ...loaded sample[%d]",loop);
                               }
                               ssampnum++;
                           }
                           [self->_delegate didLoadSFX];
//                           [synth dumpAudioBuffer:0 :16];
//                           [synth dumpAudioBuffer:1 :16];
//                           [synth dumpAudioBuffer:2 :16];

                       });
                       
                   }
                   ); //END outside dispatch
    
    
} //end loadAudioBKGD




#pragma mark -
#pragma mark AudioBufferPlayerDelegate
int dtp;
//=========(soundFX)========================================================================
- (void)audioBufferPlayer:(AudioBufferPlayer*)audioBufferPlayer
               fillBuffer:(AudioQueueBufferRef)buffer format:(AudioStreamBasicDescription)audioFormat
{
    // Lock access to the synth. This delegate callback runs on an internal
    // Audio Queue thread, and we don't want to allow the main UI thread to
    // change the Synth's state while we're filling up the audio buffer.
    [synthLock lock];
    
    // Calculate how many packets fit into this buffer. Remember that a packet
    // equals one frame because we are dealing with uncompressed audio, and a
    // frame is a set of left+right samples for stereo sound, or a single sample
    // for mono sound. Each sample consists of one or more bytes. So for 16-bit
    // mono sound, each packet is 2 bytes. For stereo it would be 4 bytes.
    int packetsPerBuffer = buffer->mAudioDataBytesCapacity / audioFormat.mBytesPerPacket;
    
    // Let the Synth write into the buffer. Note that we could have made Synth
    // be the AudioBufferPlayerDelegate, but I like to separate the synthesis
    // part from the audio engine. The Synth just knows how to fill up buffers
    // in a particular format and does not care where they come from.
    int packetsWritten = [synth fillBuffer:buffer->mAudioData frames:packetsPerBuffer];
    
    // We have to tell the buffer how many bytes we wrote into it.
    buffer->mAudioDataByteSize = packetsWritten * audioFormat.mBytesPerPacket;
    [synthLock unlock];
}  //end fillBuffer

//=====(soundFX)==========================================
-(int) hueToNote : (int) bottomnote : (int) range : (UIColor*) inColor
{
    CGColorRef colorRef = [inColor CGColor];
    float convert1 = range / 255.0;
    if (colorRef != nil) //DHS 5/23 Check for nils to prevent crashing...
    {
        int rr,gg,bb;
        const CGFloat *_lcomponents = CGColorGetComponents(colorRef);
        rr = (int)(255.0f * _lcomponents[0]);
        gg = (int)(255.0f * _lcomponents[1]);
        bb = (int)(255.0f * _lcomponents[2]);
        [self RGBtoHLS:rr :gg   : bb ];  //DIRTY GLOBALS USED HEREIN!!!
        int nextnote = bottomnote + (int)(convert1 * (float)HH);
        return nextnote;
    }

    return 0;
}

//DHS 3/20/15
//=====(soundFX)==========================================
// Let "whichizzit" be a tile #.
//   1: Is it a corner?
//Note: this has to be self-contained so it will make it out to an object!
-(void) glintmusic : (int) whichizzit : (int) psx
{
    int psy,psxy;
    int voiceoff = 0;  //different voices need different offsets
    
    if (!_enabled) return;
    
  //  psx = _plixaGame.puzzleSize;
    psy = psx;
    int izcorner = 0;
    //get corner number, going clockwize...ABCD, getit?
    //NSLog(@" GLINTMUSIC...%d",whichizzit);
    int aindex = 0;
    int bindex = psx-1;
    int cindex = psx*psy-1;
    int dindex = psx*(psy-1);
    if (whichizzit == aindex)  izcorner = 1;  //Corner A
    if (whichizzit == bindex)  izcorner = 2;  //Corner B
    if (whichizzit == cindex)  izcorner = 3;  //Corner C
    if (whichizzit == dindex)  izcorner = 4;  //Corner D
    //if (!izcorner) return; //Bail unless it's a corner for now...
    //OK, lets get a hue-based puzzle:
    int phues[36];
    //int rr,gg,bb;
    int i;
    int numoctaves = 6;
    int numnotes   = 12*numoctaves;
    int bottomnote = 50 - (numnotes/2); //Middle C is 60?
    //float convert1 = numnotes / 255.0;
    int nextnote = 0;
    int off1,off2;
    
    for (i=0;i<36;i++) phues[i] = 0; //DHS 11/4
    //NSLog(@" note range: %d to %d",bottomnote,bottomnote+12*numoctaves);
    //DHS ASSUMES puzzlecolors[] array is preloaded!
    for(i = 0;i<psx*psy && (puzzleColors[i] != nil);i++) //DHS 5/23 Add nil check , crashlytics found another crash
    {
//DHS 6/3/18 TOSS THIS AFTER A WEEK OR SO IF IT STILL WORKS...
//        CGColorRef colorRef = [puzzleColors[i] CGColor];
//        if (colorRef != nil) //DHS 5/23 Check for nils to prevent crashing...
//        {
//            const CGFloat *_lcomponents = CGColorGetComponents(colorRef);
//            rr = (int)(255.0f * _lcomponents[0]);
//            gg = (int)(255.0f * _lcomponents[1]);
//            bb = (int)(255.0f * _lcomponents[2]);
//            //populates globals HH, SS, VV
//            [self RGBtoHLS:rr :gg   : bb ];
//
//            //RGBtoHLS ( rr , gg , bb);
//            //NSLog(@" p[%2d] RGB: %3d,%3d,%3d : HLS: %3d %3d %3d",i,rr,gg,bb,HH,LL,SS);
//            nextnote = bottomnote + (int)(convert1 * (float)HH);
//            //NSLog(@" note is: %d",nextnote);
//            int inkeynote = [synth makeSureNoteisInKey:  wkey : nextnote];
//            phues[i] = inkeynote; //store da notes mon!
//        }
//DHS 6/3/18 NEW
        nextnote = [self hueToNote:bottomnote :numnotes :puzzleColors[i]];
        int wkey = 0; //MAJOR
        int inkeynote = [synth makeSureNoteisInKey:  wkey : nextnote];
        phues[i] = inkeynote; //store da notes mon!
//DHS 6/3/18 END NEW SECTION

    }
    
    //OK, time to construct our arpeggiato.....
    int sample = 8;  //8/25 We are having trouble w/ 0 sample!
    //int level12 = [self computeLevel : gallerySize : gallerySkill];
    int gain = 10;  //gain will go up as we go along...
    int gainstep = (int)(100.0f/(float)psx);
    int pan  = 20; //Start at leftish...
    int panstep;
    if (izcorner == 2 || izcorner == 3)
    {
        pan = 230; //Rightish?
        panstep = -gainstep;
    }
    else
    {
        pan = 20;
        panstep = gainstep;
    }
    int ind1,ind2,ind3,ind4,ind1step,ind2step;
    int note1,note2;
    //DHS 5/4 speed up glint music
    int timestep = 30/psx;
//    int timestep = 80/psx;
    //NSLog(@" g/p/tsteps...%d,%d,%d",gainstep,panstep,timestep);
    
    [synth setDetune: 1];
    //    Corner graphic:
    //
    //      A       B
    //
    //      D       C
    //
    ind1 = ind2 = ind3 = ind4 = 0;
    ind1step = ind2step = 0;
    if (izcorner > 0) switch (izcorner)
    {
        case 1: // A: play notes from B and D
            ind1 = bindex;
            ind1step = -1;
            ind2 = dindex;
            ind2step = -psx;
            break;
        case 2: // B: play notes from A and C
            ind1 = aindex;
            ind1step = 1;
            ind2 = cindex;
            ind2step = -psx;
            break;
        case 3: // C: play notes from B and D
            ind1 = bindex;
            ind1step = psx;
            ind2 = dindex;
            ind2step = 1;
            break;
        case 4: // D: play notes from C and A
            ind1 = cindex;
            ind1step = -1;
            ind2 = aindex;
            ind2step = psx;
            break;
    }
    else //Not a corner? let's find the neighbors...
    {
        psxy = psx*psy;
        ind1 = whichizzit - 1;   //L neighbor
        ind2 = whichizzit - psx; //T neighbor
        ind3 = whichizzit + 1;   //R Neighbor
        ind4 = whichizzit + psx; //B neighbor
        
        //keep 'em legal!
        if (ind1 < 0)     ind1 += psxy;
        if (ind1 >= psxy) ind1 -= psxy;
        if (ind2 < 0)     ind2 += psxy;
        if (ind2 >= psxy) ind2 -= psxy;
        if (ind3 < 0)     ind3 += psxy;
        if (ind3 >= psxy) ind3 -= psxy;
        if (ind4 < 0)     ind4 += psxy;
        if (ind4 >= psxy) ind4 -= psxy;
    }
    
    //NSLog(@" corneriz %d ind1/2 %d %d  , ind1/2 steps %d %d",izcorner,ind1,ind2,ind1step,ind2step);
    off1 = off2 = 0;
    if (izcorner > 0)
    {
        for(i=0;i<psx;i++) //OK make some noise!!!
        {
            note1 = phues[ind1];
            note2 = phues[ind2];
            if (!i) //first time thru? adjust our notes to fit...
            {
                //Bounce off bottom of keyboard...
                off1 = 0;
                while (note1 < 40)
                {
                    off1+=12;
                    note1+=12;
                }
                off2 = 0;
                while (note2 < 40)
                {
                    off2+=12;
                    note2+=12;
                }
                //Bounce off top of needed...
                if (off1 == 0) while (note1 > 80)
                {
                    off1-=12;
                    note1-=12;
                }
                if (off2 == 0) while (note2 > 80)
                {
                    off2-=12;
                    note2-=12;
                }
            }
            else //normal nonzero loop? apply our "bounce" offsets...
            {
                note1+=off1;
                note2+=off2;
            }
            //NSLog(@"loop[%d] 1st indexes %d %d notes %d %d",i,ind1,ind2,note1,note2);
            [synth setGain:gain];
            [synth setPan:pan];
            //NSLog(@" Playnote1: %d gain %d pan %d",note1,gain,pan);
            //NSLog(@" Playnote2: %d gain %d pan %d",note2,gain,pan);
            [synth playNoteWithDelay:voiceoff+note1:sample:SAMPLE_VOICE:timestep];
            [synth playNoteWithDelay:voiceoff+note2:sample:SAMPLE_VOICE:timestep];
            
            pan+=panstep;
            gain+=gainstep;
            ind1+=ind1step;
            ind2+=ind2step;
            //NSLog(@"        2nd indexes %d %d",ind1,ind2);
        } //end for i
    }
    else //Non-corner, play neighbors then center tile
    {
        //First play neighbors, set low gain...
        [synth setGain:30];
        [synth setPan:20]; //Left
        note1 = 30+phues[ind1];
        [synth playNoteWithDelay:voiceoff+note1:sample:SAMPLE_VOICE:0];
        [synth setPan:128]; //Center
        note1 = 30+phues[ind2];
        [synth playNoteWithDelay:voiceoff+note1:sample:SAMPLE_VOICE:4]; //DHS 5/4 was 5
        [synth setPan:200]; //RIght
        note1 = 30+phues[ind3];
        [synth playNoteWithDelay:voiceoff+note1:sample:SAMPLE_VOICE:7]; //DHS 5/4 was 10
        [synth setPan:128]; //Center
        note1 = 30+phues[ind4];
        [synth playNoteWithDelay:voiceoff+note1:sample:SAMPLE_VOICE:10]; //DHS 5/4 was 15
        note2 = 30+phues[whichizzit];
        [synth setGain:130]; //Louder
        [synth setPan:128]; //Center
        //DHS 5/4 speed up note play
        [synth playNoteWithDelay:note2:sample:SAMPLE_VOICE:25]; //was 50
    }
    
    return;
} //end glintmusic


//======(Hue-Do-Ku)==========================================
// The idea is we will take the puzzle colors, and make
//   notes from them... these notes get played as glints go off.
//    a corner will sound different than a middle point, etc.
// ..uses playNoteWithDelay : (int) midiNote : (int) wnum : (int) type : (int) delayms
// Generates canned note cascades for sfx... allows for delayed muzak too!
- (void) muzak : (int)which : (int) mtimeoff
{
    
    int note;
    int t = 0;
    switch(which)
    {
        case 0:   // L/R Sound
            note = 64;  //
            [synth setDetune: 1];
            [synth setGain:22];
            [synth setPan:20];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:mtimeoff];
            note+=2;
            [synth setPan:80];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+20];
            note+=3;
            [synth setPan:140];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+30];
            note+=4;
            [synth setPan:200];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+50];
            break;
        case 1: //R/L sound
            note = 64;  //
            [synth setDetune: 1];
            [synth setGain:22];
            [synth setPan:200];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:mtimeoff];
            note+=2;
            [synth setPan:140 ];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+20];
            note+=3;
            [synth setPan:80];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+30];
            note+=4;
            [synth setPan:20];
            [synth playNoteWithDelay:note:0:SAMPLE_VOICE:t+50];
            break;
            
    }
} //end muzak


//=====(soundFX)==========================================
- (void)audioBufferPlayer:(AudioBufferPlayer*)audioBufferPlayer
              clearBuffer:(AudioQueueBufferRef)buffer format:(AudioStreamBasicDescription)audioFormat
{
    [synthLock lock];
    int packetsPerBuffer = buffer->mAudioDataBytesCapacity / audioFormat.mBytesPerPacket;
    int packetsWritten = [synth clearBuffer:buffer->mAudioData frames:packetsPerBuffer];
    buffer->mAudioDataByteSize = packetsWritten * audioFormat.mBytesPerPacket;
    [synthLock unlock];
}  //end clearBuffer

//Used in glintmusic of all things...

//-----------=UTILS=---------------=UTILS=---------------=UTILS=-----
// DHS: gets a hue value from a color...
//-(void) RGBtoHLS (int) R : (int) G : (int) B
- (void) RGBtoHLS : (int) RR : (int) GG : (int) BB
{
    int cMax,cMin;      /* max and min RGB values */
    int  Rdelta,Gdelta,Bdelta; /* intermediate value: % of spread from max */
    
    /* calculate lightness */
    cMax = fmax( fmax(RR,GG), BB);
    cMin = fmin( fmin(RR,GG), BB);
    LL = ( ((cMax+cMin)*HLSMAX) + RGBMAX )/(2*RGBMAX);
    
    if (cMax == cMin) {            /* r=g=b --> achromatic case */
        SS = 0;                   /* saturation */
        HH = 0;					 /* hue */
        //NSLog(@"bad hue... RGB %d %d %d",R,G,B);
    }
    else {                        /* chromatic case */
        /* saturation */
        if (LL <= (HLSMAX/2))
            SS = ( ((cMax-cMin)*HLSMAX) + ((cMax+cMin)/2) ) / (cMax+cMin);
        else
            SS = ( ((cMax-cMin)*HLSMAX) + ((2*RGBMAX-cMax-cMin)/2) )
            / (2*RGBMAX-cMax-cMin);
        
        /* hue */
        Rdelta = ( ((cMax-RR)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin);
        Gdelta = ( ((cMax-GG)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin);
        Bdelta = ( ((cMax-BB)*(HLSMAX/6)) + ((cMax-cMin)/2) ) / (cMax-cMin);
        
        if (RR == cMax)
        {
            HH = Bdelta - Gdelta;
            //NSLog(@"H1... bgdel %d %d",Bdelta,Gdelta);
        }
        else if (GG == cMax)
        {
            HH = (HLSMAX/3) + Rdelta - Bdelta;
            //NSLog(@"H2... bgdel %d %d",Rdelta,Bdelta);
        }
        else /* BB == cMax */
        {
            HH = ((2*HLSMAX)/3) + Gdelta - Rdelta;
            //NSLog(@"H3... grdel %d %d",Gdelta,Rdelta);
        }
        
        while (HH < 0)
            HH += HLSMAX;
        while (HH > HLSMAX)
            HH -= HLSMAX;
        //NSLog(@" hls %d %d %d",HH,LL,SS);
    }
} //end RGBtoHLS


-(void) testit1
{
    [synth testit1];
}

@end
