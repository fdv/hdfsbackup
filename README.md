# HDFS Backup

HDFS backup is a quick and dirty backup tool using a HDFS cluster as a backend. It uses [Colin Marc HDFS client](https://github.com/colinmarc/hdfs) and 2 configuration files:

- hdfsbackup.cfg
- includes.cfg

The HDFS client is expected to be named gohdfs to avoid conflicts with the legitimate HDFS one.

Usage:

```
./hdfsbackup.sh
```