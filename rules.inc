# Generic rules for building all types of files in this project

DEP	= $(OBJECTS:%.o=%.d)

.SUFFIXES:	.c .y .l

%.c:%.y
	$(YACC) -o $@ -d $<

%.c:%.l
	$(LEX) -o$@ $<

%.o:%.c
	$(CC) $(CFLAGS) $(CFLAGS_TANSH) $(INCDIRS) -o $@ -c $<

%.d:%.c
	@echo -n Creating dependencies for $<...
	@$(CC) -M $(CFLAGS) $(CFLAGS_TANSH) $(INCDIRS) -c $< > $@
	@echo " Done"
