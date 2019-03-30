//
//    ____              _   _     ____                  
//   / ___| _   _ _ __ | |_| |__ |  _ \  __ ___   _____ 
//   \___ \| | | | '_ \| __| '_ \| | | |/ _` \ \ / / _ \
//    ___) | |_| | | | | |_| | | | |_| | (_| |\ V /  __/
//   |____/ \__, |_| |_|\__|_| |_|____/ \__,_| \_/ \___|
//           |___/                                      
//				 
// SynthDave: Polyphone synth AND sample player...
// First built April 2011; reworked in June!
// DHS April 14 2012: add harmony voice : synth 3-way harmony...
// DHS 1/8/13: Added enums for keysigs
// DHS 1/17/13 Added PERCKIT_VOICE type
// DHS 2/13: Add port. vars, add recording vars.
// DHS 5/10/13: Add new param, timetrax
// DHS 5/20/13: Add MIDI support
// OOGIECAM VERSION:
//  DHS 8/9/13: First Release? WOW! Within a week from inception!
// DHS 1/23/14: ARC-based version for RoadieTrip
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioFile.h>
#import <Foundation/Foundation.h>


#define MAX_TONE_EVENTS 64


//Possible states for a ToneEvent.
typedef enum
{
	STATE_INACTIVE = 0,    ///< ToneEvent is not used for playing a tone
	STATE_PRESSED = 1,     ///< ToneEvent is still playing normally
	STATE_SUSTAINED = 2,   ///< ToneEvent is at sustain level...
	STATE_RELEASED = 3,    ///< ToneEvent is released and ringing out
    STATE_MONOFADEOUT = 4, ///< Used in MONO voicemode: Fade voice out ASAP
}
ToneEventState;


typedef enum
{
	WAVE_SINE   = 0,  // Sine Wave (original code)
	WAVE_SAW    = 1,  // Sawtooth Wave
	WAVE_SQUARE = 2,  // Square Wave (need duty cycle??)
	WAVE_RAMP   = 3,  // Ramp Wave
	WAVE_NOISE  = 4,  // Noise Wave (Repeats, not really noise??)
}
ToneWaves;

typedef enum
{
	KEY_MAJOR       = 0,   
	KEY_MINOR       = 1,   
	KEY_LYDIAN      = 2,   
	KEY_PHRYGIAN    = 3,   
	KEY_MIXOLYDIAN  = 4,   
	KEY_LOCRIAN     = 0,   
	KEY_EGYPTIAN    = 0,   
	KEY_HUNGARIAN   = 0,   
	KEY_ALGERIAN    = 0,   
	KEY_JAPANESE    = 0,   
	KEY_CHINESE     = 0,   
	KEY_CHROMATIC   = 0,   
}
ToneKeysigs;

#define MAJOR_KEY 0
#define MINOR_KEY 1
#define LYDIAN_KEY 2
#define PHRYGIAN_KEY 3
#define MIXOLYDIAN_KEY 4
#define LOCRIAN_KEY 5
#define EGYPTIAN_KEY 6
#define HUNGARIAN_KEY 7
#define ALGERIAN_KEY 8
#define JAPANESE_KEY 9
#define CHINESE_KEY 10
#define CHROMATIC_KEY 11



//arpeggiator stuff:
#define ARP_PARAM_NOTE 0
#define ARP_PARAM_WNUM 1
#define ARP_PARAM_TYPE 2
#define ARP_PARAM_GAIN 3
#define ARP_PARAM_MONO 4
#define ARP_PARAM_LPAN 5
#define ARP_PARAM_RPAN 6
#define ARP_PARAM_TIME 7

// Describes a tone.
typedef struct
{
	ToneEventState state;   ///< the state of the tone
	int waveNum;            ///< OK, what is the synth wave type???
	int midiNote;           ///< the MIDI note number of the tone
    float pitch;            //usually constant, changes during portamento...
	float phase;            ///< current step for the oscillator
	int envAttack;          //  ADSR Support...
	int envDecay;           //  ADSR Support... 
	int envSustain;         //  ADSR Support...
	int envRelease;         //  ADSR Support...
	int toneType;           //  Synth/Perc/etc
	int detune;             //  Samples only: 0=NO pitch shift, 1=pitchshift
	int mono;               //  Monophonic Synth/Sample mode... 0 by default
	float envStep;          ///< for stepping through the envelope
	float envDelta;         ///< how fast we're stepping through the envelope
	float gain;             ///<   note loudness
	float lpan;             ///<   lpan  0.0 to 1.0
	float rpan;             ///<   ppan  0.0 to 1.0
    float portstep,portval; //used ONLY with portamento,step=999999 means NONE
    int timetrax;
    int portcount;
    int un;
    int infinite;           //Synth ONLY, holds note forever...
}
ToneEvent;

//Synth AND sampler is in one object....
#define MAX_SAMPLES 256 //OK, we will hold up to this many samples at once...
#define MAX_QUEUE 32  //queue size for notes played between quant steps
#define MAX_ARP 256  // arpeggiator size...
#define MAX_SAMPLE_SIZE 1000000   //HDK: new max size, allows for ambient bkgd music
#define TWOBYTESAMPLERANGE 65535.0

@interface Synth : NSObject
{
    float masterTune;   //DHS 1/11/13 new overall tuning, +/- .5 semitone
    float masterLevel;
	float sampleRate;   ///< output will be generated for this sample rate
	float gain;         ///< attenuation factor to prevent clipping
    int newUnique;
	int midiDev,midiChan;   //MIDI output support, midiDev=0 means MIDI OFF
	float finalMixGain;    // Final total output volume...
    float aFactor,bFactor;   //used in sin/cos mixed waves
    float *sBufs[MAX_SAMPLES];       // First five bufs are canned synth waves, rest are samples....
    float *sEnvs[MAX_SAMPLES];       // we need envelopes for each synth!
	int sElen[MAX_SAMPLES];          // envelope lengths...
	int sBufLens[MAX_SAMPLES];
	int sBufChans[MAX_SAMPLES];      //1 = mono, 2=stereo
	int sineLength;                  ///< size of sine look-up table
	int envLength[MAX_SAMPLES];      ///< size of envelope look-up table
	int envDataLength[MAX_SAMPLES];      ///< amount of table space taken up by env...
	int envIsUp[MAX_SAMPLES]; //DHS 1/8/13: this was a single var...
	int detune;         ///< overall detune flag...
	int mono;           ///< mono/poly mode
	ToneEvent tones[MAX_TONE_EVENTS];
    int queuePtr,arpPtr;
    int arpPlayPtr;
    float noteQueue[16][MAX_QUEUE];
    float arpQueue[16][MAX_ARP];   //Arpeggiator: voice/note/volume/pan
	/// fundamental frequencies for all MIDI note numbers
	float pitches[256];
    int numPVoices;
    int numSVoices;
    float glpan,grpan; //temp pan settings: call setPan right before playnote!
    float gporto;
    int gportlast; // temp portamento settings
    int timetrax;
    int recording,reclength,recptr,recsize;
    int needToMailAudioFile;
    int infinite;           //Synth ONLY, holds note forever...
    NSString *recFileName;
    double arpTime;
    NSTimer *arptimer;
    
    int uniqueVoiceCounter;   //set to 0, increments every time playnote is called...
    int monoLastUnique;
    
    int gotSample,sampleSize;

    unsigned short *swave;
    int swaveSize;
    int sPacketSize,sNumPackets,sChans;  //sample channels...
    
    
    float lvolbuf[16];
    float rvolbuf[16];
    int lrvolptr,lrvolmod;
    AudioFileID WAVfileID;
    
    short *audioRecBuffer;

}

#define NULL_VOICE -1
#define SYNTH_VOICE 0
#define PERCUSSION_VOICE 1
#define PERCKIT_VOICE 2
#define SAMPLE_VOICE 3
#define HARMONY_VOICE 4
#define MIDITRACK_VOICE 5
#define SYNTHA_DEFAULT			4.0;
#define SYNTHD_DEFAULT			2.0;
#define SYNTHS_DEFAULT			20.0;
#define SYNTHSL_DEFAULT			40.0;
#define SYNTHR_DEFAULT			20.0;
#define SYNTHDUTY_DEFAULT		50.0;

-(void)startRecording:(int)newlen;
-(void)stopRecording:(int)cancel;
- (void)writeOutputSampleFile:(NSString *)name :(NSString *)type;
 
// Initializes the Synth.
- (id)initWithSampleRate:(float)sampleRate;
- (int)getNeedToMailAudioFile; 
- (void)setNeedToMailAudioFile:(int)n;
- (int)getSVoiceCount ;
- (int)getPVoiceCount ;
- (float)getLVolume ;
- (float)getRVolume ;
-(NSString *)getAudioOutputFileName;

//DHS set master tune
- (void)setMasterTune:(int)nt;
- (void)setMasterLevel:(float)nl;
- (void)equalTemperament;
- (void)resetArp;
// Schedules a new note for playing.
//* If there are no more open slots (i.e. the polyphony limit is reached), then 
//* this new note is simply ignored.
// UMM type is synth voice #??? sample #??
- (void)playNote:(int)midiNote :(int)wnum :(int)type;
- (void)playNoteWithDelay:(int)midiNote : (int) wnum : (int) type : (int) delayms;
- (void)playPitchedNote:(float)pitch :(int)wnum;
- (void)queueNote:(int)midiNote :(int)wnum :(int)type;
- (void)emptyQueue;

//  Releases a note that is currently playing.
// If more than one tone with the corresponding MIDI note number is playing, 
//  they will all be released.

- (int)makeSureNoteisInKey: (int) wkey : (int) note;

- (int)clearBuffer:(void*)buffer frames:(int)frames;
- (int)fillBuffer:(void*)buffer frames:(int)frames;
- (void)buildEnvelope:(int)which ;
- (void)buildaWaveTable: (int) which :(int) type;
- (void)buildSampleTable:(int) which;
- (void)buildRampTable: (int) which;
- (void)buildSineTable: (int) which;
- (void)buildNoiseTable: (int) which;
- (void)buildSawTable: (int) which;
- (void)buildSquareTable: (int) which;
- (void)cleanupNotes:(int)which;
- (void)decrVoiceCount:(int)n;
- (void)dumpAudioBuffer : (int) which : (int) size;
- (float)getADSR: (int)which : (int)where ;
- (int)getNoteCount;
- (int)getEnvDataLen:(int)which  ;
- (int)getUniqueCount; 
- (void)incrVoiceCount:(int)n;
- (void)setMonoUN: (int)un ;
- (void)releaseAllNotes;
- (void)releaseNoteByBin:(int)n;
- (void)releaseAllNotesByWaveNum:(int)wn  ;
- (void)releaseNote:(int)midiNote :(int)wnum;
- (void)setGain: (int)newGainInt ;
- (void)setInfinite:(int)n;
- (void)setPan: (int)newPanInt ;
- (void)setPortamento: (int)pn ;
- (void)setPortLast: (int)lastnote ;
- (void)setAttack: (int)newVal ;
- (void)setDecay: (int)newVal ;
- (void)setSustain: (int)newVal; 
- (void)setSustainL: (int)newVal; 
- (void)setRelease: (int)newVal ;
- (void)setDuty: (int)newVal ;
- (void)setSampOffset: (int)newVal; 
- (void)setDetune: (int)newVal ;
- (void)setMono: (int)newVal ;
- (void)setTimetrax: (int)newVal ;
- (void)setMIDI: (int)mdev :(int)mchan;
- (void)setMidiOn: (int)onoff ;
- (int) getMidiOn;  


-(void) testit1;

- (void)loadSample:(NSString *)name :(NSString *)type ;

@end
