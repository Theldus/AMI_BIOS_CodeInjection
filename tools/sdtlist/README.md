# sdtlist
`sdtlist` is a tool that, given the 1B module of an AMIBIOS8 BIOS, lists all the
SMM handlers (i.e., the SMM Dispatch Table) present in that module and their
respective physical positions in the file.

The main idea is to be able to explore the existing modules and modify them
freely as needed.

## Building & Usage
Build and execute as follows:

```bash
# Build
$ make
cc sdt.c -Wall -Wextra -pedantic -O2 -c -o sdt.o
cc   sdt.o   -o sdt

# Execute
./sdt amibody.1b 
>> Found SMI dispatch table!
Size: 360 bytes
Entries: 15
Start file offset: 0x65cb1

>> SMI dispatch table entries:
Entry 0:
  Name: $SMICA
  Handle SMI ptr:  0xa8c86e4b
  Handle SMI foff: 0x47969
Entry 1:
  Name: $SMISS
  Handle SMI ptr:  0xa8c885b5
  Handle SMI foff: 0x490d3
Entry 2:
  Name: $SMIPA
  Handle SMI ptr:  0xa8c8891c
  Handle SMI foff: 0x4943a
Entry 3:
  Name: $SMISI
  Handle SMI ptr:  0xa8c89f7b
  Handle SMI foff: 0x4aa99
Entry 4:
  Name: $SMIX5
  Handle SMI ptr:  0xa8c89fd2
  Handle SMI foff: 0x4aaf0
Entry 5:
  Name: $SMIBP
<snip>
```

## References
[.:: A Real SMM Rootkit ::.](http://phrack.org/issues/66/11.html)
