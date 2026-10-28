const assert = require('assert'), fs = require('fs'), vm = require('vm'), path = require('path');
const context = {DataView:undefined};
context.self=context;
vm.createContext(context);
vm.runInContext('delete Object.getPrototypeOf(Uint8Array.prototype).subarray;',context);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Resources/legacy-es5.js'),'utf8'), context);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Resources/legacy-es3.js'),'utf8'), context);
vm.runInContext('var a=new Uint8Array([1,2,3]);var view=a.subarray(-2);view[0]=7;if(a[1]!==7||view.length!==2||a.subarray(Infinity).length!==0)throw Error("subarray shared buffer/bounds");',context);
vm.runInContext('var b=new ArrayBuffer(16);var d=new DataView(b,4,8);d.setUint32(0,0x12345678,true);if(d.getUint32(0,true)!==0x12345678||d.getUint32(0,false)!==0x78563412)throw Error("DataView endian/offset");d.setFloat32(4,1.5,true);if(d.getFloat32(4,true)!==1.5)throw Error("DataView float");',context);
const source='var x={return:7,default:8}; var text="x.return {return:9}"; var re=/x.return/; /* x.return */ x.return+x.default;';
const converted=context.YTLegacyPlayerScript(source);
assert(converted.includes('x["return"]') && converted.includes('"return":7'));
assert(converted.includes('"x.return {return:9}"') && converted.includes('/x.return/') && converted.includes('/* x.return */'));
assert.strictEqual(vm.runInNewContext(source),vm.runInNewContext(converted));
assert.strictEqual(context.YTLegacyPlayerScript('if(true)/x.return/.test("x.return");'), 'if(true)/x.return/.test("x.return");');
assert.strictEqual(context.YTLegacyPlayerScript('switch(x){default:break;}'), 'switch(x){default:break;}');
const nested='(0,eval)("var nested={return:7}; nested.return;");';
assert.strictEqual(vm.runInContext(context.YTLegacyPlayerScript(nested,true),context),7);
assert.strictEqual(context.YTLegacyPlayerScript(nested),nested);
assert.strictEqual(context.YTLegacyPlayerScript('var s="(0,eval)(x)";',true),'var s="(0,eval)(x)";');
if(process.argv[2]) {
 const player=fs.readFileSync(process.argv[2],'utf8');
 const adapted=context.YTLegacyPlayerScript(player);
 new Function(adapted);
 fs.writeFileSync(process.argv[2]+'.es3.js',adapted);
}
console.log('PASS reserved properties; strings, comments and regex unchanged; player compiles');
