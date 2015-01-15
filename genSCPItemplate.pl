#!/usr/bin/env perl
#
use strict;
use v5.10;
use Cwd qw(cwd abs_path);
use Data::Dumper;
use File::Basename;
use File::Spec::Functions;

############ MAIN VAR DEFS ###########
my $paramsFileName = './PARAMS';
our $appName = getCurrFolder(); #and the desired app name is given by the folder we're in.
#globally useful regular expressions.  All of these expressions collect named variables, which can be accessed
#after matching in the special hash %+, individual elements as: %+{name}.
my $lhs = '(?<lhs>[\w\/\.\(\)\$\-\[\]]*)';
my $rhs = '(?<rhs>[\w\/\.\(\)\$\-\[\]]*)';
my $cmd = '(?<cmd>[\w]*)';
my $op = '(?<op>[\=\+]+)';
my $comment = '(?<comment>\#.*)';
my $hook = '(?<hook>[a-z]+)[\s]*\<(?<position>[^\<\>]+)\>';
my $va1 = '^[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*' . $comment . '$';
my $va2 = '^[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*$';
my $hVa1 = '^[\s]*' . $cmd . '[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*' . $hook . '[\s]*' . $comment . '$';
my $hVa2 = '^[\s]*' . $cmd . '[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*' . $hook . '[\s]*$';
my $cmdVa1 = '^[\s]*' . $cmd . '[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*' . $comment . '$';
my $cmdVa2 = '^[\s]*' . $cmd . '[\s]*' . $lhs . '[\s]*' . $op . '[\s]*' . $rhs . '[\s]*$';
our $varAssign = $va1 . '|' . $va2;  #note: regex2 | regex2 gives "short circuit" or "left most" matching.
our $cmdVarAssign = $hVa1 . '|' . $hVa2 . '|' . $cmdVa1 . '|' . $cmdVa2;
our $headingDef = '^[\s]*[\@][\s]*' . $lhs . '[\s]*(?<remainder>[^\n]*)';
our $whoAmI = basename($0);


######### MAIN ###########

my %desiredHash = parseParams(\$paramsFileName,\%ENV); #also populates some entries in %ENV

#say Dumper(\%desiredHash);

my @outStr = HoHoHstr(\%desiredHash);
#say Dumper(\%desiredHash);
for my $line (@outStr) {
    say $line;
}
say "Parsing of PARAMS complete";

#ensure we're in $TOP
system(('cd',"$ENV{TOP}"));

#create backups for re-installation
system(('mkdir','install'));
system(('cp','genSCPItemplate.pl',"$ENV{TOP}/install/"));
system(('cp','PARAMS',"$ENV{TOP}/install/"));
system(('cp','devAPPNAME.proto',"$ENV{TOP}/install/")) if (-e 'devAPPNAME.proto');
system(('cp','devAPPNAME.db',"$ENV{TOP}/install/")) if (-e 'devAPPNAME.db');
system(('cp','st.cmd',"$ENV{TOP}/install/")) if (-e 'st.cmd');

#call perl template creation scripts
system(("$ENV{ASYN}/bin/$ENV{EPICS_HOST_ARCH}/makeSupport.pl","-A","$ENV{ASYN}","-B","$ENV{EPICS_BASE}","-t","streamSCPI","$appName"));
system(("rm","-rf","configure"));
system(("$ENV{EPICS_BASE}/bin/$ENV{EPICS_HOST_ARCH}/makeBaseApp.pl","-a","$ENV{EPICS_HOST_ARCH}","-t","ioc",$appName . $ENV{APP_SUFFIX}));
system(("$ENV{EPICS_BASE}/bin/$ENV{EPICS_HOST_ARCH}/makeBaseApp.pl","-a",$ENV{EPICS_HOST_ARCH},"-t","ioc","-i",$appName . $ENV{APP_SUFFIX}));

#change the names of the .proto and .db to match the directory name
my $protoFile = 'dev' . $appName . '.proto';
my $dbFile = 'dev' . $appName . '.db';
system(("mv",'devAPPNAME.proto',$protoFile)) if (-e 'devAPPNAME.proto');
system(("mv",'devAPPNAME.db',$dbFile)) if (-e 'devAPPNAME.db');

# edit what was created to suit our application
for my $fileKey (keys %desiredHash) {
    fixFile(\$fileKey,$desiredHash{$fileKey},\%ENV);
}

## move the .proto and .db into place if we have them.
system(("cp",$protoFile,'./' . $appName . 'Sup/')) if (-e $protoFile);
system(("cp",$dbFile,'./' . $appName . 'Sup/')) if (-e $dbFile);
system(("rm","-rf",$protoFile)) if (-e $protoFile);
system(("rm","-rf",$dbFile)) if (-e $dbFile);

# edit the st.cmd file if it exists and move it into place
my $stCmd = 'st.cmd';
my $stCmdPath = catfile($ENV{TOP},$stCmd);
system(("chmod","u+x",$stCmd));
system(("cp",$stCmd,'./iocBoot/' . 'ioc' . $appName . '/')) if (-e $stCmd);
system(("rm","-rf",$stCmd)) if (-e $stCmd);

system(("make"));


########### SUB-ROUTINES ############
sub getCurrFolder {
    my @s = split(/\//, cwd());
    my $output = undef;
    $output = $s[-1] if ($s[-1] ne "");
    $output = $s[-2] if ($s[-1] eq "");
    return $output if defined $output || die "what the shit?";
}

sub sanitizeDirectory {
    #expects a string pointer in @_[0]
    #this function just removes double slashes that can happen when you macro expand
    my $string = shift(@_);
    $$string =~ s/\/\//\//g;
}

sub safeHashMerge {
    #expects two hash pointers in @_
    #adds keys and values to first hash from second if they don't exist already
    my $hashA = shift(@_);
    my $hashB = shift(@_);
    while ( my ($key, $val) = each($hashB) ) {
        unless (exists $$hashA{$key}) {
            $$hashA{$key} = $val;
        }
    }
}

sub hashMerge {
    #expects two hash pointers in @_
    #adds keys and values to first hash from second, overwriting if they already exist
    my $hashA = shift(@_);
    my $hashB = shift(@_);
    while ( my ($key, $val) = each($hashB) ) {
        $$hashA{$key} = $val;
    }
}


sub replaceMacroInString {
    #expects two pointers in @_: 
    #first: the string to be searched and replaced; we will modify it directly
    #second: a hash (passed by reference) of valid macros and their values
    #third (optional): <left bracket> Macros are of the form $<left bracket>NAME<right bracket>
    #default is $(NAME), but you can also have $[NAME] or ${NAME}. Third argument is left bracket
    #fourth (optional): <right bracket> (see above)
    #fifth (optional): a second hash to pull definitions from (usually the environment hash) (passed as reference)
    my $inputString = shift(@_); #pull string pointer from @_
    my $macroPointer = shift(@_); #pull hash pointer from @_
    my ($lb, $rb, $envHash) = @_;
    $lb = '(' unless defined $lb;
    $rb = ')' unless defined $rb;
    $lb = '\\' . $lb;
    $rb = '\\' . $rb;
    my $macroPattern = '\$' . $lb . '([\w]*)' . $rb;
    my @macroMatches = $$inputString =~ m/$macroPattern/g; #get all the keys in the string
    for my $key (@macroMatches) {
        if (exists $$macroPointer{$key}) {
            my $repStr = undef;
            if (ref($$macroPointer{$key}) eq 'HASH') {
                $repStr = $$macroPointer{$key}{RHS}[0];
            }
            else { 
                $repStr = $$macroPointer{$key};
             }
            $$inputString =~ s/\$$lb$key$rb/$repStr/;

        }
        else {
            #check the $envHash to see if there's a match
            if (exists $$envHash{$key}) {
                $$inputString =~ s/\$$lb$key$rb/$$envHash{$key}/;
            }
            else {
                $$inputString =~ s/\$$lb$key$rb/<UNDEFINED MACRO>/;
            }
        }
    }
}

sub parseParams {
    #expects a string pointer to a file name in @_[0] and a hash pointer containing environment variables
    my $filename = abs_path(${shift(@_)}); #abs_path expands any symbolic links to prevent ambiguity
    my $envHash = shift(@_);
        #add some defaults to the environment, but yield to variables in the shell environment
        safeHashMerge($envHash, {'TOP' => cwd()});
        safeHashMerge($envHash, {'APP_NAME' => $appName});
        safeHashMerge($envHash, {'APP_SUFFIX' => ""});
    my $fh = undef;
    open($fh,"<",$filename) || die "$0: can't open PARAMS file for reading: $!";
    my @fileArray = <$fh>; #read in file to array of lines
    close($fh) || die "$0: can't close the file.  Weird! $!";
    my %varHash = ();
    my $currentKey = undef;
    my $openScope = undef;
    my @scopeChecker = ();
    my $currLine = 0;
    for my $line (@fileArray) {
        $currLine++;
        #first look to see if a variable is being defined out of a scope block.  If so, add it to hash of macro vars.
        unless (defined $openScope) {
            if  ($line =~ /$varAssign/) {
                #macros defined within the script have absolute precedence (they will overwrite)
                my $lhs = $+{lhs};
                my $rhs = $+{rhs};
                replaceMacroInString(\$rhs,$envHash); #allow expansion with previous definitions.
                hashMerge($envHash,{$lhs => $rhs}); #skip assignment operator (it must be =) and I don't care about the comments.
                next;
            }
        }
        #match a file direction, getting: 1: directory, 2: everything afterwards (delimited from previous by white space)
        if ($line =~ /$headingDef/) {
            $currentKey = $+{lhs};
            replaceMacroInString(\$currentKey,$envHash);
            $line = $+{remainder};
        }
        @scopeChecker = ($line =~  /^[\s]*\{(.*)/);
        if (scalar(@scopeChecker)!=0)
        {
            $openScope = 1;
            $line = @scopeChecker[0];
            @scopeChecker = ();
        }
        if (defined $openScope) {
            #match a variable assignment, getting: 1: varname, 2: assignment operator, 3: assigned directory, 4: optional comment
            my @subMatches = ($line =~ /$cmdVarAssign/);
            if ($line =~ /$cmdVarAssign/) {
                my $cmdType = $+{cmd}; #cmd key always exists if match
                my $lhs = $+{lhs}; #as does lhs key
                my $rhs = $+{rhs};
                replaceMacroInString(\$lhs,$envHash); #expand macros in LHS
                sanitizeDirectory(\$lhs); #sanitize LHS            
                replaceMacroInString(\$rhs,$envHash); #expand macros in RHS
                sanitizeDirectory(\$rhs); #sanitize RHS
                my $hook = exists $+{hook} ? $+{hook} : undef;
                my $pos = exists $+{position} ? $+{position} : undef;
                my $comment = exists $+{comment} ? $+{comment} : undef;
                
                if (exists $varHash{$currentKey}{$cmdType}{$lhs}) {
                    push(@{ $varHash{$currentKey}{$cmdType}{$lhs}{OP} },         $+{op});
                    push(@{ $varHash{$currentKey}{$cmdType}{$lhs}{RHS} },        $rhs);
                    push(@{ $varHash{$currentKey}{$cmdType}{$lhs}{HOOK} },       $hook);
                    push(@{ $varHash{$currentKey}{$cmdType}{$lhs}{POS} },        $pos);
                    push(@{ $varHash{$currentKey}{$cmdType}{$lhs}{COMMENT} },    $comment);
                }
                else {
                    $varHash{$currentKey}{$cmdType}{$lhs}{OP} =      [$+{op}];
                    $varHash{$currentKey}{$cmdType}{$lhs}{RHS} =     [$rhs];
                    $varHash{$currentKey}{$cmdType}{$lhs}{HOOK} =    [$hook];
                    $varHash{$currentKey}{$cmdType}{$lhs}{POS} =     [$pos];
                    $varHash{$currentKey}{$cmdType}{$lhs}{COMMENT} = [$comment];                         
                }
            }
        }
        undef $openScope if $line =~ /^[^\}^\n]*\}.*/;
    }
    return %varHash;
}

sub findHookLine {
    my ($fArrPtr, $posStr) = @_;
    my $match = undef;
    my $c = 0;
    for my $line (@$fArrPtr) {
        my $match = $line =~ /$posStr/;
        last if $match;
        $c++;
    }
    return $c;
}

sub fixFile {
    #here we expect:
    # 1. a string pointer in @_[0] giving a file name
    # 2. a hash pointer in @_[1] giving the variables (as keys) and the values to replace.
    # If the variables don't exist in the file, then we add them.
    # 3. environment variable hash reference
    my $fileName = abs_path(${shift(@_)});
    my $targetHash = shift(@_);
    my $envHash = shift(@_);
    open(my $fh,"+<",$fileName) || die "$0: can't open $fileName for updating: $!";
    my @fileSlurp = <$fh>; #slurp it up.
    close($fh) || die "$0: can't close $fileName. Weird! $!";
    my @satedKeys = ();
    my $lineNum = 0;
    my $endOfIntroComments = 0;
    my $findIntroComments = 1;
    for my $line (@fileSlurp) {
        my $commentFinder = ($line =~ /^[s]*[\#]+[.]*/);
        if ($commentFinder && defined($findIntroComments)) {
            $endOfIntroComments++;
        }
        else {
            undef $findIntroComments;
        }
        if ($line =~ /$varAssign/) {
            my $lhs = $+{lhs};
            if (exists $$targetHash{ensure}{$lhs}) {
                #do not replace if assignment operator is +=, instead splice into the line after.
                my @insertionString = Hstr($lhs,$$targetHash{ensure}); #may be several lines, so we loop over them.
                my $insertCounter = 0;
                for my $repLine (@insertionString) {
                    if ($$targetHash{ensure}{$lhs}{OP}[$insertCounter] eq "+=") {
                        #check for a hook
                        my $splicePoint = undef;
                        if (defined $$targetHash{ensure}{$lhs}{HOOK}[$insertCounter]) {
                            my $hookLine = findHookLine(\@fileSlurp,$$targetHash{ensure}{$lhs}{POS}[$insertCounter]);
                            $splicePoint = $hookLine+1 if ($$targetHash{ensure}{$lhs}{HOOK}[$insertCounter] eq 'after');
                            $splicePoint = $hookLine-1 if ($$targetHash{ensure}{$lhs}{HOOK}[$insertCounter] eq 'before');
                            #say "found hook \"$$targetHash{ensure}{$lhs}{POS}[$insertCounter]\" for $lhs";
                        }
                        else {
                            #say "no hook found for $lhs, but op was +=";
                            $splicePoint = $lineNum+1;
                        }
                        #say "\t inserting at line $splicePoint";
                        splice @fileSlurp, $splicePoint, 0, $repLine;
                    }
                    else { #otherwise replace the line
                        #say "replacing line $lineNum for $lhs";
                        splice @fileSlurp, $lineNum, 1, $repLine; 
                    }
                    $insertCounter++;
                }
                delete($$targetHash{ensure}{$lhs});
            }
        }
        $lineNum++;
    }
    my @unsatedKeys = keys %{$$targetHash{ensure}};
    for my $key (@unsatedKeys) {
        my @insertionString = Hstr($key,$$targetHash{ensure});
        my $c = 0;
        for my $repLine (@insertionString) {
            my $splicePoint = undef;
            if (defined $$targetHash{ensure}{$key}{HOOK}[$c]) {
                my $hookLine = findHookLine(\@fileSlurp,$$targetHash{ensure}{$key}{POS}[$c]);
                $splicePoint = $hookLine+1 if ($$targetHash{ensure}{$key}{HOOK}[$c] eq 'after');
                $splicePoint = $hookLine-1 if ($$targetHash{ensure}{$key}{HOOK}[$c] eq 'before');
                #say "unsated $key: found hook \"$$targetHash{ensure}{$key}{POS}[$c]\", inserting at line $splicePoint";
            }
            else {
                $splicePoint = $endOfIntroComments;
            }
            splice @fileSlurp, $splicePoint, 0, $repLine;
            $c++;
        }
    }
    #now we loop back again over the file and replace any thing defined with "define" command.
    my $counter = 0;
    #hack: I need to add the ability to put in empty strings.  I'll stuff them in the $envHash
    hashMerge($envHash,{'EMPTY' => ' '});
    for my $line (@fileSlurp) {
        #my $oldLine = $line;
        replaceMacroInString(\$line,$$targetHash{define},'[',']',$envHash);
        #say "replaced $oldLine with: $line" if ($oldLine ne $line);
        @fileSlurp[$counter] = $line;
        $counter++;
    }
    #write out the file
    open(my $fh,">",$fileName) || die "$0: can't open $fileName for clobbering: $!";
    chomp(@fileSlurp);
    for my $line (@fileSlurp) {
        say $fh $line;
    }
    close($fh) || die "$0: can't close $fileName.  Weird! $!";
}

sub Hstr {
    #pretty prints our variable assignment Hash, given 1. LHS key and 2. ref to hash of hash
    my $lhs = shift(@_);
    my $HoH = shift(@_);
    my @output = ();
    my $c = 0;
    #say ref($$HoH{$lhs}{RHS});
    #say @{$$HoH{$lhs}{RHS}}; 
    for my $rhs (@{$$HoH{$lhs}{RHS}}) {
        #note: I do not pretty print comments because apparently whoever wrote the RELEASE
        #parser did not allow for end-of-line comments.  They prevent proper building.
        #other files parse them correctly.  Easier to just not write end of line comments anywhere.
        $output[$c] = $lhs . ' ' . $$HoH{$lhs}{OP}[$c] . ' ' . $rhs;
        $c++;
    }
    return @output;
}

sub HoHstr {
    #cover the problem of printing: Hash (Left Hand Keys) of a Hash (known keys: OP, RHS, and COMMENTS), where RHS may contain an array
    #returns a list of strings corresponding to a line by line print of the HoH.
    my $HoH = shift(@_);
    my @output = ();
    my $counter = 0;
    for my $cmd (keys %$HoH) {
        push(@output,$cmd);
        for my $lhs (keys %{$$HoH{$cmd}}) {
            my @strings = Hstr($lhs,$$HoH{$cmd});
            for my $line (@strings) {
                push(@output,"\t" . $line);
            }
        }
    }
    return @output;
}

sub HoHoHstr {
    my $inHash = shift(@_);
    my @output = ();
    for my $fileKey (keys %$inHash) {
        my @strings = HoHstr($$inHash{$fileKey});
        push(@output, $fileKey);
        for my $line (@strings) {
            push(@output, "\t" . $line);
        }
    }
    return @output;
}
