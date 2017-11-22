# ea-profiler

## What it does
It watches a given PID or command to run, and it’s children to gather {avg, max, min} stats such as CPU, memory, max threads, file descriptors, etc. It outputs all this in a valid json object for easy parsing with jq command or python, etc..

### Examples

* profile a pigz command which compresses a file called /tmp/sda1 and sends result to /dev/null
`/opt/ea/bin/profiler --cmd="pigz -c /tmp/sda1 >/dev/null " --out=/tmp/profiler.out --stdout /tmp/profiler.stdout --stdin /tmp/profiler.stdin`

* Example of grabbing memory usage info from the above profiler output:
$ `jq .rollup.memory_info /tmp/profiler.out`
{
  "rss": {
    "avg": 4430990,
    "max": 4509696,
    "min": 0
  },
  "vms": {
    "avg": 176024200,
    "max": 178647040,
    "min": 0
  }
}

* Example of grabbing the number of threads from the above profiler output:
$ `jq .rollup.num_threads /tmp/profiler.out`
{
  "avg": 4,
  "max": 5,
  "min": 1
}


* One nice way to use it, is to create a BASH function:
`profile() {
    /opt/ea/bin/profiler --cmd="$*" --out=/tmp/profiler.out --stdout /tmp/profiler.stdout --stdin /tmp/profiler.stdin
 }`

So you can just call it like this: (notice the quotes are necessary for anything that would be grabbed by your shell, like ‘>’):
$ `profile "pigz -c /tmp/sda1 >/dev/null"`

Full stats collected:
* connections
* cpu_percent
* cpu_times
  * system
  * user
* io_counters
  * read_bytes
  * read_count
  * write_bytes
  * write_count
* memory_info
  * rss
  * vms
* memory_info_ex
  * data
  * dirty
  * lib
  * rss
  * shared
  * text
  * vms
* memory_maps
* memory_percent
* num_ctx_switches
  * involuntary
  * voluntary
* num_fds
* num_threads
* open_files
* pid
* threads

