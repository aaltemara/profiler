#!/usr/bin/python
"""
Profile a command, giving max/avg threads, mem, i/o, etc..
"""

import copy
import subprocess
import argparse
import psutil
import time
import sys


## Config

DEFAULTS = {'cmd': 'md5sum /tmp/random',
            'poll_freq': 1,
            'cpu_threshold': .01,
            }


## Classes

class Profiler():
    popen = None
    pid = None
    cmd = None
    p = None
    proc_infos = []
    aspect_infos = {}
    max_aspect_infos = {}
    min_aspect_infos = {}
    avg_aspect_infos = {}

    num_polls = 0

    aspects = {'sum_num_threads': True,
               'sum_running_threads': True,
               'sum_memory_pss': True,
               'sum_memory_swap': True,
               'sum_memory_dirty': True,
               'avg_cpu_percent': True,
               'accum_cpu_percent': False,
               'sum_cpu_percent': True,
               'accum_name': False,
               'accum_pid': False,
               }


    def __init__(self, **kwargs):
        if 'cmd' in kwargs:
            self.cmd = kwargs['cmd']
        elif 'pid' in kwargs:
            self.pid = kwargs['pid']
            self.p = psutil.Process(self.pid)


    def __init__(self, **kwargs):
        if 'cmd' in kwargs:
            self.cmd = kwargs['cmd']
        elif 'pid' in kwargs:
            self.pid = kwargs['pid']
            self.p = psutil.Process(self.pid)


    def run(self):
        print "Executing {0}".format(self.cmd)
        self.popen = subprocess.Popen(self.cmd, shell=True)
        if self.popen.pid:
            self.pid = self.popen.pid
            self.p = psutil.Process(self.pid)


    def watch(self):
        print "Watching command with pid: {0}".format(self.pid)

        while self.p.is_running():
            if self.poll_aspects():
                self.rollup_aspects()
                self.report_aspects()
                time.sleep(DEFAULTS['poll_freq'])
            else:
                break

        print "Process {0} has exited".format(self.pid)


    def poll_aspects(self):
        #print "Entered poll_aspects"

        self.poll_proc_infos()
        if not len(self.proc_infos):
            return False

        self.num_polls += 1
        self.aspect_infos = {}

        for aspect in self.aspects.keys():
            #print "Polling aspect: {0}".format(aspect)
            self.aspect_infos[aspect] = self.get_aspect(aspect)

        return True


    def rollup_aspects(self):
        #print "Entered rollup_aspects"

        #import pdb; pdb.set_trace()
        for aspect in self.aspects.keys():

            # Only rollup specific aspects
            if self.aspects[aspect]:
                #print "Rolling up: {0}".format(aspect)

                # The first time through, init the rollup aspect_infos with our current values
                if not aspect in self.max_aspect_infos:
                    self.max_aspect_infos[aspect] = self.aspect_infos[aspect]
                    self.min_aspect_infos[aspect] = self.aspect_infos[aspect]
                    self.avg_aspect_infos[aspect] = self.aspect_infos[aspect]

                    continue

                if self.aspect_infos[aspect] > self.max_aspect_infos[aspect]:
                    print "New max {0}: {1} (old: {2})".format(aspect, self.aspect_infos[aspect], self.max_aspect_infos[aspect])
                    self.max_aspect_infos[aspect] = self.aspect_infos[aspect]

                if self.aspect_infos[aspect] < self.min_aspect_infos[aspect]:
                    print "New min {0}: {1} (old: {2})".format(aspect, self.aspect_infos[aspect], self.min_aspect_infos[aspect])
                    self.min_aspect_infos[aspect] = self.aspect_infos[aspect]

                self.avg_aspect_infos[aspect] = (self.avg_aspect_infos[aspect] * self.num_polls + self.aspect_infos[aspect])/self.num_polls

    def report_aspects(self):
        #print "Entered report_aspects"

        for aspect in self.aspects.keys():
            if self.aspects[aspect]:
                rollup_info = ", Max: {0}, Min: {1}, Avg: {2}".format(self.max_aspect_infos[aspect],
                                                                      self.min_aspect_infos[aspect],
                                                                      self.avg_aspect_infos[aspect])
            else:
                rollup_info = ""

            print "{0} Now: {1}{2}".format(aspect, self.aspect_infos[aspect], rollup_info)
        print


    def poll_proc_infos(self):
        procs = self.p.children(recursive=True)
        procs.append(self.p)

        self.proc_infos = []
        for proc in procs:
            try:
                self.proc_infos.append(proc.as_dict())
            except:
                #print "Couldn't get proc: {0}".format(proc.pid)
                pass


    def get_aspect(self, aspect):
        proc_infos = self.proc_infos

        prefix = aspect.split('_')[0]
        aspect = '_'.join(aspect.split('_')[1:])

        #import pdb; pdb.set_trace()
        if aspect == 'num_threads':
            aspect_infos = [proc['num_threads'] for proc in proc_infos]

        elif aspect == 'running_threads':
            aspect_infos = [proc['num_threads'] for proc in proc_infos if self.is_running(proc)]

        elif aspect == 'memory_pss':
            aspect_infos = [proc['memory_full_info'].pss for proc in proc_infos]

        elif aspect == 'memory_swap':
            aspect_infos = [proc['memory_full_info'].swap for proc in proc_infos]

        elif aspect == 'memory_dirty':
            aspect_infos = [proc['memory_full_info'].dirty for proc in proc_infos]

        elif aspect == 'cpu_percent':
            aspect_infos = [proc['cpu_percent'] for proc in proc_infos]

        elif aspect == 'name':
            aspect_infos = [proc['name'] for proc in proc_infos]

        elif aspect == 'pid':
            aspect_infos = [proc['pid'] for proc in proc_infos]

        else:
            raise "Unknown Aspect"
        
        if prefix == 'sum':
            result = sum(aspect_infos)
        elif prefix == 'avg':
            result = sum(aspect_infos)/len(proc_infos)
        elif prefix == 'accum':
            result = aspect_infos

        return result


    def is_running(self, p):
        try:
            (pid, percent) = (p['pid'], p['cpu_percent'])
            running = percent > DEFAULTS['cpu_threshold']
        except:
            running = False

        return running

## Functions

def parse_args():
    parser = argparse.ArgumentParser(description='Profile a command')
    parser.add_argument('--cmd',
                        action='store',
                        help='Command to profile')
    parser.add_argument('--pid',
                        action='store',
                        type=int,
                        help='Process ID to profile')
    return parser.parse_args()


def main():
    args = parse_args()

    if args.cmd:
        profiler = Profiler(cmd=args.cmd)
        profiler.run()

    elif args.pid:
        profiler = Profiler(pid=args.pid)

    else:
        print "You must specify --cmd or --pid"
        sys.exit(1)

    profiler.watch()


## Main

main()
