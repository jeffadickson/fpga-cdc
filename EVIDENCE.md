# Imported verification evidence

The recorded simulation and formal evidence predates this standalone repository.
It was imported with the example, not rerun as part of the move. Workspace paths
inside logs, JSON, scripts and compressed trace archives were normalized to the
new repository name. These are therefore normalized historical artifacts, not
byte-for-byte original logs. No assertions, RTL behavior, bounds or result statuses
were changed. Original source hashes remain historical provenance; the earlier
formal checkpoint uses older properties than the expanded suite.

The wide expanded safety result retains its original 120-second timeout. Its
unchanged-bound 300-second retry passed; the effective summary includes that
retry and the other 29 passing checks. Both attempt logs remain in the archive.
