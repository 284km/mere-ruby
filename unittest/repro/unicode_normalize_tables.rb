# Load the actual generated Unicode tables and their interpolated regexps.
require 'unicode_normalize/normalize'
p [UnicodeNormalize::REGEXP_D.encoding.name,
   UnicodeNormalize::REGEXP_C.encoding.name,
   UnicodeNormalize::REGEXP_K.encoding.name]
