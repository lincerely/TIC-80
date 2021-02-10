// MIT License

// Copyright (c) 2020 Vadim Grigoruk @nesbox // grigoruk@gmail.com

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#include "api.h"
#include "core.h"

#include <string.h>

#define ENVELOPE_FREQ_SCALE 2
#define SECONDS_PER_MINUTE 60
#define NOTES_PER_MUNUTE (TIC80_FRAMERATE / NOTES_PER_BEAT * SECONDS_PER_MINUTE)
#define PIANO_START 8

static const u16 NoteFreqs[] = { 0x10, 0x11, 0x12, 0x13, 0x15, 0x16, 0x17, 0x18, 0x1a, 0x1c, 0x1d, 0x1f, 0x21, 0x23, 0x25, 0x27, 0x29, 0x2c, 0x2e, 0x31, 0x34, 0x37, 0x3a, 0x3e, 0x41, 0x45, 0x49, 0x4e, 0x52, 0x57, 0x5c, 0x62, 0x68, 0x6e, 0x75, 0x7b, 0x83, 0x8b, 0x93, 0x9c, 0xa5, 0xaf, 0xb9, 0xc4, 0xd0, 0xdc, 0xe9, 0xf7, 0x106, 0x115, 0x126, 0x137, 0x14a, 0x15d, 0x172, 0x188, 0x19f, 0x1b8, 0x1d2, 0x1ee, 0x20b, 0x22a, 0x24b, 0x26e, 0x293, 0x2ba, 0x2e4, 0x310, 0x33f, 0x370, 0x3a4, 0x3dc, 0x417, 0x455, 0x497, 0x4dd, 0x527, 0x575, 0x5c8, 0x620, 0x67d, 0x6e0, 0x749, 0x7b8, 0x82d, 0x8a9, 0x92d, 0x9b9, 0xa4d, 0xaea, 0xb90, 0xc40, 0xcfa, 0xdc0, 0xe91, 0xf6f, 0x105a, 0x1153, 0x125b, 0x1372, 0x149a, 0x15d4, 0x1720, 0x1880 };
STATIC_ASSERT(count_of_freqs, COUNT_OF(NoteFreqs) == NOTES * OCTAVES + PIANO_START);
STATIC_ASSERT(tic_sound_register, sizeof(tic_sound_register) == 16 + 2);
STATIC_ASSERT(tic_sample, sizeof(tic_sample) == 66);
STATIC_ASSERT(tic_track_pattern, sizeof(tic_track_pattern) == 3 * MUSIC_PATTERN_ROWS);
STATIC_ASSERT(tic_track, sizeof(tic_track) == 3 * MUSIC_FRAMES + 3);
STATIC_ASSERT(tic_music_cmd_count, tic_music_cmd_count == 1 << MUSIC_CMD_BITS);
STATIC_ASSERT(tic_sound_state_size, sizeof(tic_sound_state) == 4);

static inline s32 getTempo(const tic_track* track) { return track->tempo + DEFAULT_TEMPO; }
static inline s32 getSpeed(const tic_track* track) { return track->speed + DEFAULT_SPEED; }

static s32 tick2row(const tic_track* track, s32 tick)
{
    // BPM = tempo * 6 / speed
    return tick * getTempo(track) * DEFAULT_SPEED / getSpeed(track) / NOTES_PER_MUNUTE;
}

static s32 row2tick(const tic_track* track, s32 row)
{
    return row * getSpeed(track) * NOTES_PER_MUNUTE / getTempo(track) / DEFAULT_SPEED;
}

static inline s32 param2val(const tic_track_row* row)
{
    return (row->param1 << 4) | row->param2;
}

static void update_amp(blip_buffer_t* blip, tic_sound_register_data* data, s32 new_amp)
{
    s32 delta = new_amp - data->amp;
    data->amp += delta;
    blip_add_delta(blip, data->time, delta);
}

static inline s32 freq2period(s32 freq)
{
    enum
    {
        MinPeriodValue = 10,
        MaxPeriodValue = 4096,
        Rate = CLOCKRATE * ENVELOPE_FREQ_SCALE / WAVE_VALUES
    };

    if (freq == 0) return MaxPeriodValue;

    return CLAMP(Rate / freq - 1, MinPeriodValue, MaxPeriodValue);
}

static inline s32 getAmp(const tic_sound_register* reg, s32 amp)
{
    enum { AmpMax = (u16)-1 / 2 };
    return (amp * AmpMax / MAX_VOLUME) * reg->volume / MAX_VOLUME / TIC_SOUND_CHANNELS;
}

static void runEnvelope(blip_buffer_t* blip, const tic_sound_register* reg, tic_sound_register_data* data, s32 end_time, u8 volume)
{
    s32 period = freq2period(reg->freq * ENVELOPE_FREQ_SCALE);

    for (; data->time < end_time; data->time += period)
    {
        data->phase = (data->phase + 1) % WAVE_VALUES;

        update_amp(blip, data, getAmp(reg, tic_tool_peek4(reg->waveform.data, data->phase) * volume / MAX_VOLUME));
    }
}

static void runNoise(blip_buffer_t* blip, const tic_sound_register* reg, tic_sound_register_data* data, s32 end_time, u8 volume)
{
    // phase is noise LFSR, which must never be zero 
    if (data->phase == 0)
        data->phase = 1;

    s32 period = freq2period(reg->freq);

    for (; data->time < end_time; data->time += period)
    {
        data->phase = ((data->phase & 1) * (0b11 << 13)) ^ (data->phase >> 1);
        update_amp(blip, data, getAmp(reg, (data->phase & 1) ? volume : 0));
    }
}

static s32 calcLoopPos(const tic_sound_loop* loop, s32 pos)
{
    s32 offset = 0;

    if (loop->size > 0)
    {
        for (s32 i = 0; i < pos; i++)
        {
            if (offset < (loop->start + loop->size - 1))
                offset++;
            else offset = loop->start;
        }
    }
    else offset = pos >= SFX_TICKS ? SFX_TICKS - 1 : pos;

    return offset;
}

static void resetSfxPos(tic_channel_data* channel)
{
    memset(channel->pos->data, -1, sizeof(tic_sfx_pos));
    channel->tick = -1;
}

static void sfx(tic_mem* memory, s32 index, s32 note, s32 pitch, tic_channel_data* channel, tic_sound_register* reg, s32 channelIndex)
{
    tic_core* core = (tic_core*)memory;

    if (channel->duration > 0)
        channel->duration--;

    if (index < 0 || channel->duration == 0)
    {
        resetSfxPos(channel);
        return;
    }

    const tic_sample* effect = &memory->ram.sfx.samples.data[index];
    s32 pos = tic_tool_sfx_pos(channel->speed, ++channel->tick);

    for (s32 i = 0; i < sizeof(tic_sfx_pos); i++)
        *(channel->pos->data + i) = calcLoopPos(effect->loops + i, pos);

    u8 volume = MAX_VOLUME - effect->data[channel->pos->volume].volume;

    if (volume > 0)
    {
        s8 arp = effect->data[channel->pos->chord].chord * (effect->reverse ? -1 : 1);
        if (arp) note += arp;

        note = CLAMP(note, 0, COUNT_OF(NoteFreqs) - 1);

        reg->freq = NoteFreqs[note] + effect->data[channel->pos->pitch].pitch * (effect->pitch16x ? 16 : 1) + pitch;
        reg->volume = volume;

        u8 wave = effect->data[channel->pos->wave].wave;
        const tic_waveform* waveform = &memory->ram.sfx.waveforms.items[wave];
        memcpy(reg->waveform.data, waveform->data, sizeof(tic_waveform));

        tic_tool_poke4(&memory->ram.stereo.data, channelIndex * 2, channel->volume.left * !effect->stereo_left);
        tic_tool_poke4(&memory->ram.stereo.data, channelIndex * 2 + 1, channel->volume.right * !effect->stereo_right);
    }
}

static void setChannelData(tic_mem* memory, s32 index, s32 note, s32 octave, s32 duration, tic_channel_data* channel, s32 volumeLeft, s32 volumeRight, s32 speed)
{
    tic_core* core = (tic_core*)memory;

    channel->volume.left = volumeLeft;
    channel->volume.right = volumeRight;

    if (index >= 0)
    {
        struct { s8 speed : SFX_SPEED_BITS; } temp = { speed };
        channel->speed = speed == temp.speed ? speed : memory->ram.sfx.samples.data[index].speed;
    }

    channel->note = note + octave * NOTES;
    channel->duration = duration;
    channel->index = index;

    resetSfxPos(channel);
}


static void setMusicChannelData(tic_mem* memory, s32 index, s32 note, s32 octave, s32 left, s32 right, s32 channel)
{
    tic_core* core = (tic_core*)memory;
    setChannelData(memory, index, note, octave, -1, &core->state.music.channels[channel], left, right, SFX_DEF_SPEED);
}

static void resetMusicChannels(tic_mem* memory)
{
    for (s32 c = 0; c < TIC_SOUND_CHANNELS; c++)
        setMusicChannelData(memory, -1, 0, 0, 0, 0, c);

    tic_core* core = (tic_core*)memory;
    memset(core->state.music.commands, 0, sizeof core->state.music.commands);
    memset(&core->state.music.jump, 0, sizeof(tic_jump_command));
}

static void stopMusic(tic_mem* memory)
{
    tic_api_music(memory, -1, 0, 0, false, false);
}

static void processMusic(tic_mem* memory)
{
    tic_core* core = (tic_core*)memory;
    tic_sound_state* sound_state = &memory->ram.sound_state;

    if (sound_state->flag.music_state == tic_music_stop) return;

    const tic_track* track = &memory->ram.music.tracks.data[sound_state->music.track];
    s32 row = tick2row(track, core->state.music.ticks);
    tic_jump_command* jumpCmd = &core->state.music.jump;

    if (row != sound_state->music.row
        && jumpCmd->active)
    {
        sound_state->music.frame = jumpCmd->frame;
        sound_state->music.row = jumpCmd->beat * NOTES_PER_BEAT;
        core->state.music.ticks = row2tick(track, sound_state->music.row);
        memset(jumpCmd, 0, sizeof(tic_jump_command));
    }

    s32 rows = MUSIC_PATTERN_ROWS - track->rows;
    if (row >= rows)
    {
        row = 0;
        core->state.music.ticks = 0;

        // If music is in sustain mode, we only reset the channels if the music stopped.
        // Otherwise, we reset it on every new frame.
        if (sound_state->flag.music_state == tic_music_stop || !sound_state->flag.music_sustain)
        {
            resetMusicChannels(memory);

            for (s32 c = 0; c < TIC_SOUND_CHANNELS; c++)
                setMusicChannelData(memory, -1, 0, 0, MAX_VOLUME, MAX_VOLUME, c);
        }

        if (sound_state->flag.music_state == tic_music_play)
        {
            sound_state->music.frame++;

            if (sound_state->music.frame >= MUSIC_FRAMES)
            {
                if (sound_state->flag.music_loop)
                    sound_state->music.frame = 0;
                else
                {
                    stopMusic(memory);
                    return;
                }
            }
            else
            {
                s32 val = 0;
                for (s32 c = 0; c < TIC_SOUND_CHANNELS; c++)
                    val += tic_tool_get_pattern_id(track, sound_state->music.frame, c);

                // empty frame detected
                if (!val)
                {
                    if (sound_state->flag.music_loop)
                        sound_state->music.frame = 0;
                    else
                    {
                        stopMusic(memory);
                        return;
                    }
                }
            }
        }
        else if (sound_state->flag.music_state == tic_music_play_frame)
        {
            if (!sound_state->flag.music_loop)
            {
                stopMusic(memory);
                return;
            }
        }
    }

    if (row != sound_state->music.row)
    {
        sound_state->music.row = row;

        for (s32 c = 0; c < TIC_SOUND_CHANNELS; c++)
        {
            s32 patternId = tic_tool_get_pattern_id(track, sound_state->music.frame, c);
            if (!patternId) continue;

            const tic_track_pattern* pattern = &memory->ram.music.patterns.data[patternId - PATTERN_START];
            const tic_track_row* trackRow = &pattern->rows[sound_state->music.row];
            tic_channel_data* channel = &core->state.music.channels[c];
            tic_command_data* cmdData = &core->state.music.commands[c];

            if (trackRow->command == tic_music_cmd_delay)
            {
                cmdData->delay.row = trackRow;
                cmdData->delay.ticks = param2val(trackRow);
                trackRow = NULL;
            }

            if (cmdData->delay.row && cmdData->delay.ticks == 0)
            {
                trackRow = cmdData->delay.row;
                cmdData->delay.row = NULL;
            }

            if (trackRow)
            {
                // reset commands data
                if (trackRow->note)
                {
                    cmdData->slide.tick = 0;
                    cmdData->slide.note = channel->note;
                }

                if (trackRow->note == NoteStop)
                    setMusicChannelData(memory, -1, 0, 0, channel->volume.left, channel->volume.right, c);
                else if (trackRow->note >= NoteStart)
                    setMusicChannelData(memory, tic_tool_get_track_row_sfx(trackRow), trackRow->note - NoteStart, trackRow->octave,
                        channel->volume.left, channel->volume.right, c);

                switch (trackRow->command)
                {
                case tic_music_cmd_volume:
                    channel->volume.left = trackRow->param1;
                    channel->volume.right = trackRow->param2;
                    break;

                case tic_music_cmd_chord:
                    cmdData->chord.tick = 0;
                    cmdData->chord.note1 = trackRow->param1;
                    cmdData->chord.note2 = trackRow->param2;
                    break;

                case tic_music_cmd_jump:
                    core->state.music.jump.active = true;
                    core->state.music.jump.frame = trackRow->param1;
                    core->state.music.jump.beat = trackRow->param2;
                    break;

                case tic_music_cmd_vibrato:
                    cmdData->vibrato.tick = 0;
                    cmdData->vibrato.period = trackRow->param1;
                    cmdData->vibrato.depth = trackRow->param2;
                    break;

                case tic_music_cmd_slide:
                    cmdData->slide.duration = param2val(trackRow);
                    break;

                case tic_music_cmd_pitch:
                    cmdData->finepitch.value = param2val(trackRow) - PITCH_DELTA;
                    break;

                default: break;
                }
            }
        }
    }

    for (s32 i = 0; i < TIC_SOUND_CHANNELS; ++i)
    {
        tic_channel_data* channel = &core->state.music.channels[i];
        tic_command_data* cmdData = &core->state.music.commands[i];

        if (channel->index >= 0)
        {
            s32 note = channel->note;
            s32 pitch = 0;

            // process chord commmand
            {
                s32 chord[] =
                {
                    0,
                    cmdData->chord.note1,
                    cmdData->chord.note2
                };

                note += chord[cmdData->chord.tick % (cmdData->chord.note2 == 0 ? 2 : 3)];
            }

            // process vibrato commmand
            if (cmdData->vibrato.period && cmdData->vibrato.depth)
            {
                static const s32 VibData[] = { 0x0, 0x31f1, 0x61f8, 0x8e3a, 0xb505, 0xd4db, 0xec83, 0xfb15, 0x10000, 0xfb15, 0xec83, 0xd4db, 0xb505, 0x8e3a, 0x61f8, 0x31f1, 0x0, 0xffffce0f, 0xffff9e08, 0xffff71c6, 0xffff4afb, 0xffff2b25, 0xffff137d, 0xffff04eb, 0xffff0000, 0xffff04eb, 0xffff137d, 0xffff2b25, 0xffff4afb, 0xffff71c6, 0xffff9e08, 0xffffce0f };
                STATIC_ASSERT(VibData, COUNT_OF(VibData) == 32);

                s32 p = cmdData->vibrato.period << 1;
                pitch += (VibData[(cmdData->vibrato.tick % p) * COUNT_OF(VibData) / p] * cmdData->vibrato.depth) >> 16;
            }

            // process slide command
            if (cmdData->slide.tick < cmdData->slide.duration)
                pitch += (NoteFreqs[channel->note] - NoteFreqs[note = cmdData->slide.note]) * cmdData->slide.tick / cmdData->slide.duration;

            pitch += cmdData->finepitch.value;

            sfx(memory, channel->index, note, pitch, channel, &memory->ram.registers[i], i);
        }

        ++cmdData->chord.tick;
        ++cmdData->vibrato.tick;
        ++cmdData->slide.tick;

        if (cmdData->delay.ticks)
            cmdData->delay.ticks--;
    }

    core->state.music.ticks++;
}

static void setSfxChannelData(tic_mem* memory, s32 index, s32 note, s32 octave, s32 duration, s32 channel, s32 left, s32 right, s32 speed)
{
    tic_core* core = (tic_core*)memory;
    setChannelData(memory, index, note, octave, duration, &core->state.sfx.channels[channel], left, right, speed);
}

static void setMusic(tic_core* core, s32 index, s32 frame, s32 row, bool loop, bool sustain)
{
    tic_mem* memory = (tic_mem*)core;

    memory->ram.sound_state.music.track = index;

    if (index < 0)
    {
        memory->ram.sound_state.flag.music_state = tic_music_stop;
        resetMusicChannels(memory);
    }
    else
    {
        for (s32 c = 0; c < TIC_SOUND_CHANNELS; c++)
            setMusicChannelData(memory, -1, 0, 0, MAX_VOLUME, MAX_VOLUME, c);

        memory->ram.sound_state.music.row = row;
        memory->ram.sound_state.music.frame = frame < 0 ? 0 : frame;
        memory->ram.sound_state.flag.music_loop = loop;
        memory->ram.sound_state.flag.music_sustain = sustain;
        memory->ram.sound_state.flag.music_state = tic_music_play;

        const tic_track* track = &memory->ram.music.tracks.data[index];
        core->state.music.ticks = row >= 0 ? row2tick(track, row) : 0;
    }
}

void tic_api_music(tic_mem* memory, s32 index, s32 frame, s32 row, bool loop, bool sustain)
{
    tic_core* core = (tic_core*)memory;

    setMusic(core, index, frame, row, loop, sustain);

    if (index >= 0)
        memory->ram.sound_state.flag.music_state = tic_music_play;
}

void tic_api_sfx(tic_mem* memory, s32 index, s32 note, s32 octave, s32 duration, s32 channel, s32 left, s32 right, s32 speed)
{
    tic_core* core = (tic_core*)memory;
    setSfxChannelData(memory, index, note, octave, duration, channel, left, right, speed);
}

static void stereo_tick_end(tic_mem* memory, tic_sound_register_data* registers, blip_buffer_t* blip, u8 stereoRight)
{
    enum { EndTime = CLOCKRATE / TIC80_FRAMERATE };
    for (s32 i = 0; i < TIC_SOUND_CHANNELS; ++i)
    {
        u8 volume = tic_tool_peek4(&memory->ram.stereo.data, stereoRight + i * 2);

        const tic_sound_register* reg = &memory->ram.registers[i];
        tic_sound_register_data* data = registers + i;

        tic_tool_is_noise(&reg->waveform)
            ? runNoise(blip, reg, data, EndTime, volume)
            : runEnvelope(blip, reg, data, EndTime, volume);

        data->time -= EndTime;
    }

    blip_end_frame(blip, EndTime);
}

void tic_core_sound_tick_start(tic_mem* memory)
{
    tic_core* core = (tic_core*)memory;

    for (s32 i = 0; i < TIC_SOUND_CHANNELS; ++i)
        memset(&memory->ram.registers[i], 0, sizeof(tic_sound_register));

    memory->ram.stereo.data = -1;

    processMusic(memory);

    for (s32 i = 0; i < TIC_SOUND_CHANNELS; ++i)
    {
        tic_channel_data* c = &core->state.sfx.channels[i];

        if (c->index >= 0)
            sfx(memory, c->index, c->note, 0, c, &memory->ram.registers[i], i);
    }
}

void tic_core_sound_tick_end(tic_mem* memory)
{
    tic_core* core = (tic_core*)memory;

    stereo_tick_end(memory, core->state.registers.left, core->blip.left, 0);
    stereo_tick_end(memory, core->state.registers.right, core->blip.right, 1);

    blip_read_samples(core->blip.left, core->memory.samples.buffer, core->samplerate / TIC80_FRAMERATE, TIC_STEREO_CHANNELS);
    blip_read_samples(core->blip.right, core->memory.samples.buffer + 1, core->samplerate / TIC80_FRAMERATE, TIC_STEREO_CHANNELS);
}
