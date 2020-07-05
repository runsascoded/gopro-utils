#!/usr/bin/env python

from argparse import ArgumentParser
from os.path import exists
from pathlib import Path
import shlex
from subprocess import check_call, check_output


def run(*args, **kwargs):
    args = [ str(arg) for arg in args if arg is not None ]
    print(f'Running: {shlex.join(args)}')
    check_call(args)


def paths(input, in_xtn, out_xtn):
    input = Path(input)
    extension = input.suffix.lower()
    if not in_xtn.startswith('.'): in_xtn = '.' + in_xtn
    if not out_xtn.startswith('.'): out_xtn = '.' + out_xtn
    assert extension == in_xtn
    output = str(input)[:-len(extension)] + out_xtn
    output = Path(output)
    return input, output


def prep_cmd(base, path, in_xtn, out_xtn, exist_ok, force, *force_args):
    assert not exist_ok or not force

    cmd = [base]

    input, output = paths(path, in_xtn, out_xtn)

    if output.exists():
        if exist_ok:
            print(f'Skipping {input}; {output} exists')
            return

        if not force:
            raise ValueError(f'{input}: output path {output} exists')

        if force_args:
            cmd += force_args
    
    return cmd, input, output
    

def mp4_to_gpmd(path, exist_ok=False, force=False):
    cmd, input, output = prep_cmd('ffmpeg', path, 'mp4', 'gpmd', exist_ok, force, '-y')
    
    import json
    streams = \
        json.loads(
            check_output([
                'ffprobe',
                '-v','error',
                '-show_entries','stream=index,codec_tag_string',
                '-of','json',
                str(input)
            ]) \
            .decode()
        )
    
    [ gpmd_stream ] = [ stream for stream in streams['streams'] if stream['codec_tag_string'] == 'gpmd' ]
    gpmd_stream_idx = gpmd_stream['index']
    
    cmd += ['-i',input,'-codec','copy','-map',f'0:{gpmd_stream_idx}','-f','rawvideo',output]
    run(*cmd)
    return output


def gpmd_to_json(path, exist_ok=False, force=False):
    cmd, input, output = prep_cmd('/go/bin/gopro2json', path, 'gpmd', 'json', exist_ok, force)
    cmd += ['-i',input,'-o',output]
    run(*cmd)
    return output


def process_input(input, exist_ok, force, max_depth):
    input = Path(input)
    extension = input.suffix.lower()
    if input.is_dir():
        if max_depth == -1 or max_depth > 0:
            next_depth = max_depth - 1 if max_depth > 0 else max_depth
            mp4s = input.glob('*.mp4') + input.glob('*.MP4')
            for mp4 in mp4s:
                process_input(mp4, exist_ok, force, next_depth)

            gpmds = input.glob('*.gpmd')
            for gpmd in gpmds:
                process_input(gpmd, exist_ok, force, next_depth)
    elif extension == '.mp4':
        gpmd = mp4_to_gpmd(input, exist_ok, force)
        json = gpmd_to_json(gpmd, exist_ok, force)
    elif extension == '.gpmd':
        gpmd = input
        json = gpmd_to_json(input, exist_ok, force)
    else:
        raise ValueError(f'Unrecognized extension {extension} ({input})')


def process_inputs(inputs, exist_ok, force, max_depth):
    for input in inputs:
        process_input(input, exist_ok, force, max_depth)


if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('input', nargs='+', help='Input .mp4 (or .gpmd) files to extract GoPro Metadata (GPMD) from')

    exist_group = parser.add_mutually_exclusive_group()
    exist_group.add_argument('-e','--exist-ok',action='store_true',help='When set, silently skip existing files')
    exist_group.add_argument('-f','--force',action='store_true',help='When set, overwrite existing output files')

    depth_group = parser.add_mutually_exclusive_group()
    depth_group.add_argument('-d','--max-depth',default=1,type=int,help='Maximum depth to traverse into directories; -1 for ♾')
    depth_group.add_argument('-r','--recursive',action='store_true',help="When set, process directories recursively (equivalent to setting --max-depth=-1; by default, one level of directories are eligible to be processed, i.e. --max-depth=1")

    args = parser.parse_args()
    inputs = args.input
    exist_ok = args.exist_ok
    force = args.force
    recursive = args.recursive
    max_depth = args.max_depth
    if recursive:
        max_depth = -1
    process_inputs(inputs, exist_ok, force, max_depth)
