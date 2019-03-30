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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AudioBufferPlayer.h"
#import "SynthDave.h"

@protocol sfxDelegate;

#define NUM_ANALSESSION_INTS    32
#define NUM_ANALSESSION_DOUBLES 16

#define MAX_SOUNDFILES 64

@interface soundFX : NSObject <AudioBufferPlayerDelegate>
{
    //Synth/SFX is managed by top VC, is it smarter to put in AppDelegate?
    NSLock* synthLock;
    float sampleRate;
    AudioBufferPlayer* player;
    Synth* synth;
    NSString *soundFileNames[MAX_SOUNDFILES];
    BOOL soundFileLoaded[MAX_SOUNDFILES];
    int soundFileCount;
    UIColor *puzzleColors[36]; //CLugey! needs puzzle colors
    
}
//@property (strong, nonatomic) NSString *versionNumber;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) double soundRandKey;
@property (nonatomic, unsafe_unretained) id <sfxDelegate> delegate; // receiver of completion messages



+ (id)sharedInstance;
-(void) loadAudio;
-(void) loadAudioBKGD : (int) immediateSampleNum;
-(int) hueToNote : (int) bottomnote : (int) range : (UIColor*) inColor; //DHS 6/3/18 new
-(void) glintmusic : (int) whichizzit : (int) psx;
-(int) makeSureNoteisInKey : (int) keysig : (int) note;

- (void) makeTicSoundWithXY : (int) which : (int) x : (int) y;
- (void) makeTicSoundWithPitchandLevel : (int) which : (int) ppitch : (int) level;
- (void) makeTicSoundWithPitchandLevelandPan : (int) which : (int) ppitch : (int) level : (int) pan;
- (void) makeTicSoundWithPitch : (int) which : (int) pitch;
- (void) muzak : (int)which : (int) mtimeoff;
- (void) releaseAllNotesByWaveNum : (int) which;
- (void) setSoundFileName : (int) index : (NSString *)sfname;
- (void) setMasterLevel : (float) level;
- (void) setPan : (int) pan;
- (void) setPuzzleColor : (int) index : (UIColor *)color;
- (void) swapPuzzleColors : (int) pfrom : (int) pto;
-(void) testit1;

//DHS 3/10
- (void) start;
- (void) stop;
@end


@protocol sfxDelegate <NSObject>
@optional
-(void) didLoadSFX;
@end


