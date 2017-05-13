# HDFS Backup

HDFS backup is a quick and dirty backup tool using a HDFS cluster as a backend. It uses [Colin Marc HDFS client](https://github.com/colinmarc/hdfs) and 2 configuration files:

- hdfsbackup.cfg
- includes.cfg

The HDFS client is expected to be named gohdfs to avoid conflicts with the legitimate HDFS one.

Usage:

```
./hdfsbackup.sh [/path/to/config.cfg]
```

Or in a crontab (better for rotation):

```
0 */4 * * * ./hdfsbackup.sh [/path/to/config.cfg]
```

If you're using a crontab, make sure you don't run more often than your hourly backup retention.

Example: if you're keeping 4 hourly backups, run 4 times a day.

## TODO

- Add backup exclusion
- See how to deal with symlinks as hdfs doesn't like them