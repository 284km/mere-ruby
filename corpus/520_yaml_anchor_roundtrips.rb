require 'psych'
shared = [1]
value = {'a'=>shared,'b'=>shared}
loaded=Psych.unsafe_load(Psych.dump(value));p loaded;p loaded['a'].equal?(loaded['b'])
a=[];a<<a;loaded=Psych.unsafe_load(Psych.dump(a));p loaded.equal?(loaded[0])
h={};h['self']=h;loaded=Psych.unsafe_load(Psych.dump(h));p loaded.equal?(loaded['self'])
[['--- &a [*a]',true],['--- *missing',true],['--- &a [*a]',false]].each do |source,aliases|
 begin
  v=Psych.load(source,aliases:aliases);p v.equal?(v[0])
 rescue =>e;p e.class.to_s;end
end
shared = {};p Psych.unsafe_load(Psych.dump([shared,shared]))
loaded=Psych.load(Psych.dump(h),aliases:true,symbolize_names:true);p loaded.equal?(loaded[:self])
S=Struct.new(:value);o=S.new;o.value=o;v=Psych.unsafe_load(Psych.dump(o));p [v.class.to_s,v.equal?(v.value)]
class Obj;attr_accessor :value;end
o=Obj.new;o.value=o;v=Psych.unsafe_load(Psych.dump(o));p [v.class.to_s,v.equal?(v.value)]
[2,3,4,9].each do |width|
 x=[1];y={'x'=>x,'y'=>x};v=Psych.unsafe_load(Psych.dump([y,y],indentation:width));p [width,v[0].equal?(v[1]),v[0]['x'].equal?(v[1]['y'])]
end
# Scalar aliases must distinguish a defined nil/false from an unknown name.
['--- [&a false, *a]', '--- [&a null, *a]', '--- [&a 7, *a]',
 '--- &a {self: *a}', "---\na: &a []\nb: *a\n"].each do |source|
 v=Psych.safe_load(source, aliases:true)
 if v.is_a?(Array)
   p [v, v[0].equal?(v[1])]
 elsif v.key?('self')
   p v.equal?(v['self'])
 else
   p v['a'].equal?(v['b'])
 end
end
p Psych.safe_load('--- "&a plain"')
p Psych.safe_load('--- "*a plain"')
Psych.unsafe_load('--- &a []')
begin
 Psych.unsafe_load('--- *a')
rescue => e
 p e.class.to_s
end
p Psych.load_stream("--- &a []\n--- &a {}\n")
begin
 Psych.load_stream("--- &a []\n--- *a\n")
rescue =>e
 p e.class.to_s
end
# Identity tracking bypasses object-level overrides and retains objects across GC.
class AnchorIdentity
 attr_accessor :value
 def hash; raise 'hash called'; end
 def eql?(_); raise 'eql? called'; end
 def __id__; raise '__id__ called'; end
 def object_id; raise 'object_id called'; end
 def instance_variables
  GC.start
  [:@value]
 end
end
obj=AnchorIdentity.new;obj.value=obj
loaded=Psych.unsafe_load(Psych.dump([obj,obj]))
p [loaded[0].equal?(loaded[1]),loaded[0].equal?(loaded[0].value)]
# A normal acyclic shared value remains usable by callers expecting a round trip.
shared=['text',{'value'=>1}]
value={'a'=>shared,'b'=>shared}
p Psych.unsafe_load(Psych.dump(value)) == value
