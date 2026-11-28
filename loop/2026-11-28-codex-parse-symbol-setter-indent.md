# Setter symbols before statement modifiers

Nokogiri's valid `undef_method :line= if method_defined?(:line=)` pushed a
statement-if scope in the local-variable/indentation tracker. Its trailing
equals sign was treated as assignment, so a later class end warned and Rails
strict warnings stopped all17 ActionMailer files before any tests ran.

Recognize a bare named setter symbol before if/unless/while/until, using the
existing colon context rules and forward encoded-name validation. The UTF8
path scans only the preceding identifier; other source encodings locate the
colon before stepping whole characters. Actual assignment and ternary
separators keep statement-if behavior. No warning suppression or preload.

Corpus996 covers separate modifiers, UTF8/Windows31J/Big5, main and require,
and real indentation warnings. All8 engine/hash/GC32 configurations match
Ruby. Corpus--both1036/1036; resumedVM1036/0fallback/0FAIL/0list differences.
Twelve source gates/default hygiene pass. Six whole CRuby files were compared
with mainc576 on both engines: all sides COMPLETE, no prior PASS lost.
test_parse retains3 evaluator/2VM failures; other five files have0F/0E.

Three alternating parse-heavy instruction pairs: upstream test_parse
evaluator-0.234%,VM-0.365%;500setter classes-0.023%/-0.086%. Startup included;
these small differences do not establish a stable performance improvement.

Fixedseed12345 test_parse RSS, three alternating pairs, KiB:
evaluator before344032/306048/267536,after328576/290416/274560;
VM before308576/342896/291504,after341712/298848/336800.
Medians306048->290416 and308576->336800. Ranges overlap. A separate initial
test_syntax RSS attempt hit an inner memory-leak-test timeout on baseline;
the complete failing observation is retained, not counted as a pass.

ActionMailer full17files was remeasured on separate integration85d7500b
(6183e249 plus only this fix/corpus996), with a fresh native install made by
that exact binary, normalGC/jobs2/seed12345/600s/2GiB. Both reference sides
COMPLETE; both Mere sides17INCOMPLETE,0MATCH/268MISSING, all other counts0.
The original warning is gone; loading next fails at a prepended Class method's
super on a module singleton class. That separate interpreter fix follows.
No bounds were hit. The record includes every file state, time and source.

Reference tools/ref_ruby.sh, clean4.0.10/a704b7cd95,Prism1.8.2,zeroextras.
Compiler9dec2ff6,mgz661a01d8; pure fix based on mainc576ee49.
No CAPI/native/VM implementation changes. Corpus1150 is another stream's.
