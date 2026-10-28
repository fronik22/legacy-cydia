/*!
 * https://github.com/es-shims/es5-shim
 * @license es5-shim Copyright 2009-2020 by contributors, MIT License
 * see https://github.com/es-shims/es5-shim/blob/master/LICENSE
 */
(function(t,e){"use strict";if(typeof define==="function"&&define.amd){define(e)}else if(typeof exports==="object"){module.exports=e()}else{t.returnExports=e()}})(this,function(){var t=Array;var e=t.prototype;var r=Object;var n=r.prototype;var i=Function;var a=i.prototype;var o=String;var f=o.prototype;var u=Number;var l=u.prototype;var s=e.slice;var c=e.splice;var v=e.push;var p=e.unshift;var h=e.concat;var y=e.join;var d=a.call;var g=a.apply;var b=Math.max;var w=Math.min;var T=Math.floor;var m=Math.abs;var S=Math.pow;var D=Math.round;var x=Math.log;var E=Math.LOG10E;var O=Math.log10||function log10(t){return x(t)*E};var I=n.toString;var j=typeof Symbol==="function"&&typeof Symbol.toStringTag==="symbol";var N;var F=Function.prototype.toString,U=/^\s*class /,$=function isES6ClassFn(t){try{var e=F.call(t);var r=e.replace(/\/\/.*\n/g,"");var n=r.replace(/\/\*[.\s\S]*\*\//g,"");var i=n.replace(/\n/gm," ").replace(/ {2}/g," ");return U.test(i)}catch(a){return false}},M=function tryFunctionObject(t){try{if($(t)){return false}F.call(t);return true}catch(e){return false}},C="[object Function]",P="[object GeneratorFunction]",N=function isCallable(t){if(!t){return false}if(typeof t!=="function"&&typeof t!=="object"){return false}if(j){return M(t)}if($(t)){return false}var e=I.call(t);return e===C||e===P};var k;var R=RegExp.prototype.exec,A=function tryRegexExec(t){try{R.call(t);return true}catch(e){return false}},J="[object RegExp]";k=function isRegex(t){if(typeof t!=="object"){return false}return j?A(t):I.call(t)===J};var Y;var z=String.prototype.valueOf,Z=function tryStringObject(t){try{z.call(t);return true}catch(e){return false}},G="[object String]";Y=function isString(t){if(typeof t==="string"){return true}if(typeof t!=="object"){return false}return j?Z(t):I.call(t)===G};var H=r.defineProperty&&function(){try{var t={};r.defineProperty(t,"x",{enumerable:false,value:t});for(var e in t){return false}return t.x===t}catch(n){return false}}();var W=function(t){var e;if(H){e=function(t,e,n,i){if(!i&&e in t){return}r.defineProperty(t,e,{configurable:true,enumerable:false,writable:true,value:n})}}else{e=function(t,e,r,n){if(!n&&e in t){return}t[e]=r}}return function defineProperties(r,n,i){for(var a in n){if(t.call(n,a)){e(r,a,n[a],i)}}}}(n.hasOwnProperty);if(r.defineProperty&&H){var B=function(){};var L={};var X={toString:L};r.defineProperty(B,"prototype",{value:X,writable:false});if((new B).toString!==L){var q=r.defineProperty;var K=r.getOwnPropertyDescriptor;W(r,{defineProperty:function defineProperty(t,e,r){var n=o(e);if(typeof t==="function"&&n==="prototype"){var i=K(t,n);if(i.writable&&!r.writable&&"value"in r){try{t[n]=r.value}catch(a){}}return q(t,n,{configurable:"configurable"in r?r.configurable:i.configurable,enumerable:"enumerable"in r?r.enumerable:i.enumerable,writable:r.writable})}return q(t,n,r)}},true)}}var Q=function isPrimitive(t){var e=typeof t;return t===null||e!=="object"&&e!=="function"};var V=u.isNaN||function isActualNaN(t){return t!==t};var _={ToInteger:function ToInteger(t){var e=+t;if(V(e)){e=0}else if(e!==0&&e!==1/0&&e!==-(1/0)){e=(e>0||-1)*T(m(e))}return e},ToPrimitive:function ToPrimitive(t){var e,r,n;if(Q(t)){return t}r=t.valueOf;if(N(r)){e=r.call(t);if(Q(e)){return e}}n=t.toString;if(N(n)){e=n.call(t);if(Q(e)){return e}}throw new TypeError},ToObject:function(t){if(t==null){throw new TypeError("can't convert "+t+" to object")}return r(t)},ToUint32:function ToUint32(t){return t>>>0}};var tt=function Empty(){};W(a,{bind:function bind(t){var e=this;if(!N(e)){throw new TypeError("Function.prototype.bind called on incompatible "+e)}var n=s.call(arguments,1);var a;var o=function(){if(this instanceof a){var i=g.call(e,this,h.call(n,s.call(arguments)));if(r(i)===i){return i}return this}return g.call(e,t,h.call(n,s.call(arguments)))};var f=b(0,e.length-n.length);var u=[];for(var l=0;l<f;l++){v.call(u,"$"+l)}a=i("binder","return function ("+y.call(u,",")+"){ return binder.apply(this, arguments); }")(o);if(e.prototype){tt.prototype=e.prototype;a.prototype=new tt;tt.prototype=null}return a}});var et=d.bind(n.hasOwnProperty);var rt=d.bind(n.toString);var nt=d.bind(s);var it=g.bind(s);if(typeof document==="object"&&document&&document.documentElement){try{nt(document.documentElement.childNodes)}catch(at){var ot=nt;var ft=it;nt=function arraySliceIE(t){var e=[];var r=t.length;while(r-- >0){e[r]=t[r]}return ft(e,ot(arguments,1))};it=function arraySliceApplyIE(t,e){return ft(nt(t),e)}}}var ut=d.bind(f.slice);var lt=d.bind(f.split);var st=d.bind(f.indexOf);var ct=d.bind(v);var vt=d.bind(n.propertyIsEnumerable);var pt=d.bind(e.sort);var ht=t.isArray||function isArray(t){return rt(t)==="[object Array]"};var yt=[].unshift(0)!==1;W(e,{unshift:function(){p.apply(this,arguments);return this.length}},yt);W(t,{isArray:ht});var dt=r("a");var gt=dt[0]!=="a"||!(0 in dt);var bt=function properlyBoxed(t){var e=true;var r=true;var n=false;if(t){try{t.call("foo",function(t,r,n){if(typeof n!=="object"){e=false}});t.call([1],function(){"use strict";r=typeof this==="string"},"x")}catch(i){n=true}}return!!t&&!n&&e&&r};W(e,{forEach:function forEach(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=-1;var i=_.ToUint32(r.length);var a;if(arguments.length>1){a=arguments[1]}if(!N(t)){throw new TypeError("Array.prototype.forEach callback must be a function")}while(++n<i){if(n in r){if(typeof a==="undefined"){t(r[n],n,e)}else{t.call(a,r[n],n,e)}}}}},!bt(e.forEach));W(e,{map:function map(e){var r=_.ToObject(this);var n=gt&&Y(this)?lt(this,""):r;var i=_.ToUint32(n.length);var a=t(i);var o;if(arguments.length>1){o=arguments[1]}if(!N(e)){throw new TypeError("Array.prototype.map callback must be a function")}for(var f=0;f<i;f++){if(f in n){if(typeof o==="undefined"){a[f]=e(n[f],f,r)}else{a[f]=e.call(o,n[f],f,r)}}}return a}},!bt(e.map));W(e,{filter:function filter(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=_.ToUint32(r.length);var i=[];var a;var o;if(arguments.length>1){o=arguments[1]}if(!N(t)){throw new TypeError("Array.prototype.filter callback must be a function")}for(var f=0;f<n;f++){if(f in r){a=r[f];if(typeof o==="undefined"?t(a,f,e):t.call(o,a,f,e)){ct(i,a)}}}return i}},!bt(e.filter));W(e,{every:function every(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=_.ToUint32(r.length);var i;if(arguments.length>1){i=arguments[1]}if(!N(t)){throw new TypeError("Array.prototype.every callback must be a function")}for(var a=0;a<n;a++){if(a in r&&!(typeof i==="undefined"?t(r[a],a,e):t.call(i,r[a],a,e))){return false}}return true}},!bt(e.every));W(e,{some:function some(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=_.ToUint32(r.length);var i;if(arguments.length>1){i=arguments[1]}if(!N(t)){throw new TypeError("Array.prototype.some callback must be a function")}for(var a=0;a<n;a++){if(a in r&&(typeof i==="undefined"?t(r[a],a,e):t.call(i,r[a],a,e))){return true}}return false}},!bt(e.some));var wt=false;if(e.reduce){wt=typeof e.reduce.call("es5",function(t,e,r,n){return n})==="object"}W(e,{reduce:function reduce(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=_.ToUint32(r.length);if(!N(t)){throw new TypeError("Array.prototype.reduce callback must be a function")}if(n===0&&arguments.length===1){throw new TypeError("reduce of empty array with no initial value")}var i=0;var a;if(arguments.length>=2){a=arguments[1]}else{do{if(i in r){a=r[i++];break}if(++i>=n){throw new TypeError("reduce of empty array with no initial value")}}while(true)}for(;i<n;i++){if(i in r){a=t(a,r[i],i,e)}}return a}},!wt);var Tt=false;if(e.reduceRight){Tt=typeof e.reduceRight.call("es5",function(t,e,r,n){return n})==="object"}W(e,{reduceRight:function reduceRight(t){var e=_.ToObject(this);var r=gt&&Y(this)?lt(this,""):e;var n=_.ToUint32(r.length);if(!N(t)){throw new TypeError("Array.prototype.reduceRight callback must be a function")}if(n===0&&arguments.length===1){throw new TypeError("reduceRight of empty array with no initial value")}var i;var a=n-1;if(arguments.length>=2){i=arguments[1]}else{do{if(a in r){i=r[a--];break}if(--a<0){throw new TypeError("reduceRight of empty array with no initial value")}}while(true)}if(a<0){return i}do{if(a in r){i=t(i,r[a],a,e)}}while(a--);return i}},!Tt);var mt=e.indexOf&&[0,1].indexOf(1,2)!==-1;W(e,{indexOf:function indexOf(t){var e=gt&&Y(this)?lt(this,""):_.ToObject(this);var r=_.ToUint32(e.length);if(r===0){return-1}var n=0;if(arguments.length>1){n=_.ToInteger(arguments[1])}n=n>=0?n:b(0,r+n);for(;n<r;n++){if(n in e&&e[n]===t){return n}}return-1}},mt);var St=e.lastIndexOf&&[0,1].lastIndexOf(0,-3)!==-1;W(e,{lastIndexOf:function lastIndexOf(t){var e=gt&&Y(this)?lt(this,""):_.ToObject(this);var r=_.ToUint32(e.length);if(r===0){return-1}var n=r-1;if(arguments.length>1){n=w(n,_.ToInteger(arguments[1]))}n=n>=0?n:r-m(n);for(;n>=0;n--){if(n in e&&t===e[n]){return n}}return-1}},St);var Dt=function(){var t=[1,2];var e=t.splice();return t.length===2&&ht(e)&&e.length===0}();W(e,{splice:function splice(t,e){if(arguments.length===0){return[]}return c.apply(this,arguments)}},!Dt);var xt=function(){var t={};e.splice.call(t,0,0,1);return t.length===1}();var Et=[0,1,2].splice(0).length===3;W(e,{splice:function splice(t,e){if(arguments.length===0){return[]}var r=arguments;this.length=b(_.ToInteger(this.length),0);if(arguments.length>0&&typeof e!=="number"){r=nt(arguments);if(r.length<2){ct(r,this.length-t)}else{r[1]=_.ToInteger(e)}}return c.apply(this,r)}},!xt||!Et);var Ot=function(){var e=new t(1e5);e[8]="x";e.splice(1,1);return e.indexOf("x")===7}();var It=function(){var t=256;var e=[];e[t]="a";e.splice(t+1,0,"b");return e[t]==="a"}();W(e,{splice:function splice(t,e){var r=_.ToObject(this);var n=[];var i=_.ToUint32(r.length);var a=_.ToInteger(t);var f=a<0?b(i+a,0):w(a,i);var u=arguments.length===0?0:arguments.length===1?i-f:w(b(_.ToInteger(e),0),i-f);var l=0;var s;while(l<u){s=o(f+l);if(et(r,s)){n[l]=r[s]}l+=1}var c=nt(arguments,2);var v=c.length;var p;if(v<u){l=f;var h=i-u;while(l<h){s=o(l+u);p=o(l+v);if(et(r,s)){r[p]=r[s]}else{delete r[p]}l+=1}l=i;var y=i-u+v;while(l>y){delete r[l-1];l-=1}}else if(v>u){l=i-u;while(l>f){s=o(l+u-1);p=o(l+v-1);if(et(r,s)){r[p]=r[s]}else{delete r[p]}l-=1}}l=f;for(var d=0;d<c.length;++d){r[l]=c[d];l+=1}r.length=i-u+v;return n}},!Ot||!It);var jt=e.join;var Nt;try{Nt=Array.prototype.join.call("123",",")!=="1,2,3"}catch(at){Nt=true}if(Nt){W(e,{join:function join(t){var e=typeof t==="undefined"?",":t;return jt.call(Y(this)?lt(this,""):this,e)}},Nt)}var Ft=[1,2].join(undefined)!=="1,2";if(Ft){W(e,{join:function join(t){var e=typeof t==="undefined"?",":t;return jt.call(this,e)}},Ft)}var Ut=function push(t){var e=_.ToObject(this);var r=_.ToUint32(e.length);var n=0;while(n<arguments.length){e[r+n]=arguments[n];n+=1}e.length=r+n;return r+n};var $t=function(){var t={};var e=Array.prototype.push.call(t,undefined);return e!==1||t.length!==1||typeof t[0]!=="undefined"||!et(t,0)}();W(e,{push:function push(t){if(ht(this)){return v.apply(this,arguments)}return Ut.apply(this,arguments)}},$t);var Mt=function(){var t=[];var e=t.push(undefined);return e!==1||t.length!==1||typeof t[0]!=="undefined"||!et(t,0)}();W(e,{push:Ut},Mt);W(e,{slice:function(t,e){var r=Y(this)?lt(this,""):this;return it(r,arguments)}},gt);var Ct=function(){try{[1,2].sort(null)}catch(t){try{[1,2].sort({})}catch(e){return false}}return true}();var Pt=function(){try{[1,2].sort(/a/);return false}catch(t){}return true}();var kt=function(){try{[1,2].sort(undefined);return true}catch(t){}return false}();W(e,{sort:function sort(t){if(typeof t==="undefined"){return pt(this)}if(!N(t)){throw new TypeError("Array.prototype.sort callback must be a function")}return pt(this,t)}},Ct||!kt||!Pt);var Rt=!vt({toString:null},"toString");var At=vt(function(){},"prototype");var Jt=!et("x","0");var Yt=function(t){var e=t.constructor;return e&&e.prototype===t};var zt={$applicationCache:true,$console:true,$external:true,$frame:true,$frameElement:true,$frames:true,$innerHeight:true,$innerWidth:true,$onmozfullscreenchange:true,$onmozfullscreenerror:true,$outerHeight:true,$outerWidth:true,$pageXOffset:true,$pageYOffset:true,$parent:true,$scrollLeft:true,$scrollTop:true,$scrollX:true,$scrollY:true,$self:true,$webkitIndexedDB:true,$webkitStorageInfo:true,$window:true,$width:true,$height:true,$top:true,$localStorage:true};var Zt=function(){if(typeof window==="undefined"){return false}for(var t in window){try{if(!zt["$"+t]&&et(window,t)&&window[t]!==null&&typeof window[t]==="object"){Yt(window[t])}}catch(e){return true}}return false}();var Gt=function(t){if(typeof window==="undefined"||!Zt){return Yt(t)}try{return Yt(t)}catch(e){return false}};var Ht=["toString","toLocaleString","valueOf","hasOwnProperty","isPrototypeOf","propertyIsEnumerable","constructor"];var Wt=Ht.length;var Bt=function isArguments(t){return rt(t)==="[object Arguments]"};var Lt=function isArguments(t){return t!==null&&typeof t==="object"&&typeof t.length==="number"&&t.length>=0&&!ht(t)&&N(t.callee)};var Xt=Bt(arguments)?Bt:Lt;W(r,{keys:function keys(t){var e=N(t);var r=Xt(t);var n=t!==null&&typeof t==="object";var i=n&&Y(t);if(!n&&!e&&!r){throw new TypeError("Object.keys called on a non-object")}var a=[];var f=At&&e;if(i&&Jt||r){for(var u=0;u<t.length;++u){ct(a,o(u))}}if(!r){for(var l in t){if(!(f&&l==="prototype")&&et(t,l)){ct(a,o(l))}}}if(Rt){var s=Gt(t);for(var c=0;c<Wt;c++){var v=Ht[c];if(!(s&&v==="constructor")&&et(t,v)){ct(a,v)}}}return a}});var qt=r.keys&&function(){return r.keys(arguments).length===2}(1,2);var Kt=r.keys&&function(){var t=r.keys(arguments);return arguments.length!==1||t.length!==1||t[0]!==1}(1);var Qt=r.keys;W(r,{keys:function keys(t){if(Xt(t)){return Qt(nt(t))}return Qt(t)}},!qt||Kt);var Vt=new Date(-0xc782b5b342b24).getUTCMonth()!==0;var _t=new Date(-0x55d318d56a724);var te=new Date(14496624e5);var ee=_t.toUTCString()!=="Mon, 01 Jan -45875 11:59:59 GMT";var re;var ne;var ie=_t.getTimezoneOffset();if(ie<-720){re=_t.toDateString()!=="Tue Jan 02 -45875";ne=!/^Thu Dec 10 2015 \d\d:\d\d:\d\d GMT[-+]\d\d\d\d(?: |$)/.test(String(te))}else{re=_t.toDateString()!=="Mon Jan 01 -45875";ne=!/^Wed Dec 09 2015 \d\d:\d\d:\d\d GMT[-+]\d\d\d\d(?: |$)/.test(String(te))}var ae=d.bind(Date.prototype.getFullYear);var oe=d.bind(Date.prototype.getMonth);var fe=d.bind(Date.prototype.getDate);var ue=d.bind(Date.prototype.getUTCFullYear);var le=d.bind(Date.prototype.getUTCMonth);var se=d.bind(Date.prototype.getUTCDate);var ce=d.bind(Date.prototype.getUTCDay);var ve=d.bind(Date.prototype.getUTCHours);var pe=d.bind(Date.prototype.getUTCMinutes);var he=d.bind(Date.prototype.getUTCSeconds);var ye=d.bind(Date.prototype.getUTCMilliseconds);var de=["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];var ge=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];var be=function daysInMonth(t,e){return fe(new Date(e,t,0))};W(Date.prototype,{getFullYear:function getFullYear(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ae(this);if(t<0&&oe(this)>11){return t+1}return t},getMonth:function getMonth(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ae(this);var e=oe(this);if(t<0&&e>11){return 0}return e},getDate:function getDate(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ae(this);var e=oe(this);var r=fe(this);if(t<0&&e>11){if(e===12){return r}var n=be(0,t+1);return n-r+1}return r},getUTCFullYear:function getUTCFullYear(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ue(this);if(t<0&&le(this)>11){return t+1}return t},getUTCMonth:function getUTCMonth(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ue(this);var e=le(this);if(t<0&&e>11){return 0}return e},getUTCDate:function getUTCDate(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ue(this);var e=le(this);var r=se(this);if(t<0&&e>11){if(e===12){return r}var n=be(0,t+1);return n-r+1}return r}},Vt);W(Date.prototype,{toUTCString:function toUTCString(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=ce(this);var e=se(this);var r=le(this);var n=ue(this);var i=ve(this);var a=pe(this);var o=he(this);return de[t]+", "+(e<10?"0"+e:e)+" "+ge[r]+" "+n+" "+(i<10?"0"+i:i)+":"+(a<10?"0"+a:a)+":"+(o<10?"0"+o:o)+" GMT"}},Vt||ee);W(Date.prototype,{toDateString:function toDateString(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=this.getDay();var e=this.getDate();var r=this.getMonth();var n=this.getFullYear();return de[t]+" "+ge[r]+" "+(e<10?"0"+e:e)+" "+n}},Vt||re);if(Vt||ne){Date.prototype.toString=function toString(){if(!this||!(this instanceof Date)){throw new TypeError("this is not a Date object.")}var t=this.getDay();var e=this.getDate();var r=this.getMonth();var n=this.getFullYear();var i=this.getHours();var a=this.getMinutes();var o=this.getSeconds();var f=this.getTimezoneOffset();var u=T(m(f)/60);var l=T(m(f)%60);return de[t]+" "+ge[r]+" "+(e<10?"0"+e:e)+" "+n+" "+(i<10?"0"+i:i)+":"+(a<10?"0"+a:a)+":"+(o<10?"0"+o:o)+" GMT"+(f>0?"-":"+")+(u<10?"0"+u:u)+(l<10?"0"+l:l)};if(H){r.defineProperty(Date.prototype,"toString",{configurable:true,enumerable:false,writable:true})}}var we=-621987552e5;var Te="-000001";var me=Date.prototype.toISOString&&new Date(we).toISOString().indexOf(Te)===-1;var Se=Date.prototype.toISOString&&new Date(-1).toISOString()!=="1969-12-31T23:59:59.999Z";var De=d.bind(Date.prototype.getTime);W(Date.prototype,{toISOString:function toISOString(){if(!isFinite(this)||!isFinite(De(this))){throw new RangeError("Date.prototype.toISOString called on non-finite value.")}var t=ue(this);var e=le(this);t+=T(e/12);e=(e%12+12)%12;var r=[e+1,se(this),ve(this),pe(this),he(this)];t=(t<0?"-":t>9999?"+":"")+ut("00000"+m(t),0<=t&&t<=9999?-4:-6);for(var n=0;n<r.length;++n){r[n]=ut("00"+r[n],-2)}return t+"-"+nt(r,0,2).join("-")+"T"+nt(r,2).join(":")+"."+ut("000"+ye(this),-3)+"Z"}},me||Se);var xe=function(){try{return Date.prototype.toJSON&&new Date(NaN).toJSON()===null&&new Date(we).toJSON().indexOf(Te)!==-1&&Date.prototype.toJSON.call({toISOString:function(){return true}})}catch(t){return false}}();if(!xe){Date.prototype.toJSON=function toJSON(t){var e=r(this);var n=_.ToPrimitive(e);if(typeof n==="number"&&!isFinite(n)){return null}var i=e.toISOString;if(!N(i)){throw new TypeError("toISOString property is not callable")}return i.call(e)}}var Ee=Date.parse("+033658-09-27T01:46:40.000Z")===1e15;var Oe=!isNaN(Date.parse("2012-04-04T24:00:00.500Z"))||!isNaN(Date.parse("2012-11-31T23:59:59.000Z"))||!isNaN(Date.parse("2012-12-31T23:59:60.000Z"));var Ie=isNaN(Date.parse("2000-01-01T00:00:00.000Z"));if(Ie||Oe||!Ee){var je=S(2,31)-1;var Ne=V(new Date(1970,0,1,0,0,0,je+1).getTime());Date=function(t){var e=function Date(r,n,i,a,f,u,l){var s=arguments.length;var c;if(this instanceof t){var v=u;var p=l;if(Ne&&s>=7&&l>je){var h=T(l/je)*je;var y=T(h/1e3);v+=y;p-=y*1e3}var d=e.parse(r);var g=isNaN(d);c=s===1&&o(r)===r&&!g?new t(d):s>=7?new t(r,n,i,a,f,v,p):s>=6?new t(r,n,i,a,f,v):s>=5?new t(r,n,i,a,f):s>=4?new t(r,n,i,a):s>=3?new t(r,n,i):s>=2?new t(r,n):s>=1?new t(r instanceof t?+r:r):new t}else{c=t.apply(this,arguments)}if(!Q(c)){W(c,{constructor:e},true)}return c};var r=new RegExp("^"+"(\\d{4}|[+-]\\d{6})"+"(?:-(\\d{2})"+"(?:-(\\d{2})"+"(?:"+"T(\\d{2})"+":(\\d{2})"+"(?:"+":(\\d{2})"+"(?:(\\.\\d{1,}))?"+")?"+"("+"Z|"+"(?:"+"([-+])"+"(\\d{2})"+":(\\d{2})"+")"+")?)?)?)?"+"$");var n=[0,31,59,90,120,151,181,212,243,273,304,334,365];var i=function dayFromMonth(t,e){var r=e>1?1:0;return n[e]+T((t-1969+r)/4)-T((t-1901+r)/100)+T((t-1601+r)/400)+365*(t-1970)};var a=function toUTC(e){var r=0;var n=e;if(Ne&&n>je){var i=T(n/je)*je;var a=T(i/1e3);r+=a;n-=a*1e3}return u(new t(1970,0,1,0,0,r,n))};for(var f in t){if(et(t,f)){e[f]=t[f]}}W(e,{now:t.now,UTC:t.UTC},true);e.prototype=t.prototype;W(e.prototype,{constructor:e},true);var l=function parse(e){var n=r.exec(e);if(n){var o=u(n[1]),f=u(n[2]||1)-1,l=u(n[3]||1)-1,s=u(n[4]||0),c=u(n[5]||0),v=u(n[6]||0),p=T(u(n[7]||0)*1e3),h=Boolean(n[4]&&!n[8]),y=n[9]==="-"?1:-1,d=u(n[10]||0),g=u(n[11]||0),b;var w=c>0||v>0||p>0;if(s<(w?24:25)&&c<60&&v<60&&p<1e3&&f>-1&&f<12&&d<24&&g<60&&l>-1&&l<i(o,f+1)-i(o,f)){b=((i(o,f)+l)*24+s+d*y)*60;b=((b+c+g*y)*60+v)*1e3+p;if(h){b=a(b)}if(-864e13<=b&&b<=864e13){return b}}return NaN}return t.parse.apply(this,arguments)};W(e,{parse:l});return e}(Date)}if(!Date.now){Date.now=function now(){return(new Date).getTime()}}var Fe=l.toFixed&&(8e-5.toFixed(3)!=="0.000"||.9.toFixed(0)!=="1"||1.255.toFixed(2)!=="1.25"||(1000000000000000128).toFixed(0)!=="1000000000000000128");var Ue={base:1e7,size:6,data:[0,0,0,0,0,0],multiply:function multiply(t,e){var r=-1;var n=e;while(++r<Ue.size){n+=t*Ue.data[r];Ue.data[r]=n%Ue.base;n=T(n/Ue.base)}},divide:function divide(t){var e=Ue.size;var r=0;while(--e>=0){r+=Ue.data[e];Ue.data[e]=T(r/t);r=r%t*Ue.base}},numToString:function numToString(){var t=Ue.size;var e="";while(--t>=0){if(e!==""||t===0||Ue.data[t]!==0){var r=o(Ue.data[t]);if(e===""){e=r}else{e+=ut("0000000",0,7-r.length)+r}}}return e},pow:function pow(t,e,r){return e===0?r:e%2===1?pow(t,e-1,r*t):pow(t*t,e/2,r)},log:function log(t){var e=0;var r=t;while(r>=4096){e+=12;r/=4096}while(r>=2){e+=1;r/=2}return e}};var $e=function toFixed(t){var e,r,n,i,a,f,l,s;e=u(t);e=V(e)?0:T(e);if(e<0||e>20){throw new RangeError("Number.toFixed called with invalid number of decimals")}r=u(this);if(V(r)){return"NaN"}if(r<=-1e21||r>=1e21){return o(r)}n="";if(r<0){n="-";r=-r}i="0";if(r>1e-21){a=Ue.log(r*Ue.pow(2,69,1))-69;f=a<0?r*Ue.pow(2,-a,1):r/Ue.pow(2,a,1);f*=4503599627370496;a=52-a;if(a>0){Ue.multiply(0,f);l=e;while(l>=7){Ue.multiply(1e7,0);l-=7}Ue.multiply(Ue.pow(10,l,1),0);l=a-1;while(l>=23){Ue.divide(1<<23);l-=23}Ue.divide(1<<l);Ue.multiply(1,1);Ue.divide(2);i=Ue.numToString()}else{Ue.multiply(0,f);Ue.multiply(1<<-a,0);i=Ue.numToString()+ut("0.00000000000000000000",2,2+e)}}if(e>0){s=i.length;if(s<=e){i=n+ut("0.0000000000000000000",0,e-s+2)+i}else{i=n+ut(i,0,s-e)+"."+ut(i,s-e)}}else{i=n+i}return i};W(l,{toFixed:$e},Fe);var Me=function(){try{return(-6.9e-11).toExponential(4)!=="-6.9000e-11"}catch(t){return false}}();var Ce=function(){try{1..toExponential(Infinity);1..toExponential(-Infinity);return true}catch(t){return false}}();var Pe=d.bind(l.toExponential);var ke=d.bind(l.toString);var Re=d.bind(l.valueOf);W(l,{toExponential:function toExponential(t){var e=Re(this);if(typeof t==="undefined"){return Pe(e)}var r=_.ToInteger(t);if(V(e)){return"NaN"}if(r<0||r>20){if(!isFinite(r)){throw new RangeError("toExponential() argument must be between 0 and 20")}return Pe(e,r)}var n="";if(e<0){n="-";e=-e}if(e===Infinity){return n+"Infinity"}if(typeof t!=="undefined"&&(r<0||r>20)){throw new RangeError("Fraction digits "+t+" out of range")}var i="";var a=0;var o="";var f="";if(e===0){a=0;r=0;i="0"}else{var u=O(e);a=T(u);var l=0;if(typeof t!=="undefined"){var s=S(10,a-r);l=D(e/s);if(2*e>=(2*l+1)*s){l+=1}if(l>=S(10,r+1)){l/=10;a+=1}}else{r=16;var c=D(S(10,u-a+r));var v=r;while(r-- >0){c=D(S(10,u-a+r));if(m(c*S(10,a-r)-e)<=m(l*S(10,a-v)-e)){v=r;l=c}}}i=ke(l,10);if(typeof t==="undefined"){while(ut(i,-1)==="0"){i=ut(i,0,-1);f+=1}}}if(r!==0){i=ut(i,0,1)+"."+ut(i,1)}if(a===0){o="+";f="0"}else{o=a>0?"+":"-";f=ke(m(a),10)}i+="e"+o+f;return n+i}},Me||Ce);var Ae=function(){try{return 1..toPrecision(undefined)==="1"}catch(t){return true}}();var Je=d.bind(l.toPrecision);W(l,{toPrecision:function toPrecision(t){return typeof t==="undefined"?Je(this):Je(this,t)}},Ae);if("ab".split(/(?:ab)*/).length!==2||".".split(/(.?)(.?)/).length!==4||"tesst".split(/(s)*/)[1]==="t"||"test".split(/(?:)/,-1).length!==4||"".split(/.?/).length||".".split(/()()/).length>1){(function(){var t=typeof/()??/.exec("")[1]==="undefined";var e=S(2,32)-1;f.split=function split(r,n){var i=String(this);if(typeof r==="undefined"&&n===0){return[]}if(!k(r)){return lt(this,r,n)}var a=[];var o=(r.ignoreCase?"i":"")+(r.multiline?"m":"")+(r.unicode?"u":"")+(r.sticky?"y":""),f=0,u,l,s,c;var p=new RegExp(r.source,o+"g");if(!t){u=new RegExp("^"+p.source+"$(?!\\s)",o)}var h=typeof n==="undefined"?e:_.ToUint32(n);l=p.exec(i);while(l){s=l.index+l[0].length;if(s>f){ct(a,ut(i,f,l.index));if(!t&&l.length>1){l[0].replace(u,function(){for(var t=1;t<arguments.length-2;t++){if(typeof arguments[t]==="undefined"){l[t]=void 0}}})}if(l.length>1&&l.index<i.length){v.apply(a,nt(l,1))}c=l[0].length;f=s;if(a.length>=h){break}}if(p.lastIndex===l.index){p.lastIndex++}l=p.exec(i)}if(f===i.length){if(c||!p.test("")){ct(a,"")}}else{ct(a,ut(i,f))}return a.length>h?nt(a,0,h):a}})()}else if("0".split(void 0,0).length){f.split=function split(t,e){if(typeof t==="undefined"&&e===0){return[]}return lt(this,t,e)}}var Ye=f.replace;var ze=function(){var t=[];"x".replace(/x(.)?/g,function(e,r){ct(t,r)});return t.length===1&&typeof t[0]==="undefined"}();if(!ze){f.replace=function replace(t,e){var r=N(e);var n=k(t)&&/\)[*?]/.test(t.source);if(!r||!n){return Ye.call(this,t,e)}var i=function(r){var n=arguments.length;var i=t.lastIndex;t.lastIndex=0;var a=t.exec(r)||[];t.lastIndex=i;ct(a,arguments[n-2],arguments[n-1]);return e.apply(this,a)};return Ye.call(this,t,i)}}var Ze="".substr&&"0b".substr(-1)!=="b";var Ge=Ze&&d.bind(f.substr);W(f,{substr:function substr(t,e){var r=t;if(t<0){r=b(this.length+t,0)}return Ge(this,r,e)}},Ze);var He="\u180e";var We=/\s/.test(He);var Be="\t\n\x0B\f\r \xa0\u1680\u180e\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u202f\u205f\u3000\u2028\u2029\ufeff".replace(/\S/g,"");var Le="\u200b";var Xe="["+Be+"]";var qe=new RegExp("^"+Xe+Xe+"*");var Ke=new RegExp(Xe+Xe+"*$");var Qe=f.trim&&(Be.trim()!==""||Le.trim()===""||He.trim()!==(We?"":He));W(f,{trim:function trim(){"use strict";if(typeof this==="undefined"||this===null){throw new TypeError("can't convert "+this+" to object")}return o(this).replace(qe,"").replace(Ke,"")}},Qe);var Ve=d.bind(String.prototype.trim);var _e=f.lastIndexOf&&"abc\u3042\u3044".lastIndexOf("\u3042\u3044",2)!==-1;W(f,{lastIndexOf:function lastIndexOf(t){if(typeof this==="undefined"||this===null){throw new TypeError("can't convert "+this+" to object")}var e=o(this);var r=o(t);var n=arguments.length>1?u(arguments[1]):NaN;var i=V(n)?Infinity:_.ToInteger(n);var a=w(b(i,0),e.length);var f=r.length;var l=a+f;while(l>0){l=b(0,l-f);var s=st(ut(e,l,a+f),r);if(s!==-1){return l+s}}return-1}},_e);var tr=f.lastIndexOf;W(f,{lastIndexOf:function lastIndexOf(t){return tr.apply(this,arguments)}},f.lastIndexOf.length!==1);var er=/^[-+]?0[xX]/;if(parseInt(Be+"08")!==8||parseInt(Be+"0x16")!==22||(We?parseInt(He+1)!==1:!isNaN(parseInt(He+1)))){parseInt=function(t){return function parseInt(e,r){if(this instanceof parseInt){new t}var n=Ve(String(e));var i=u(r)||(er.test(n)?16:10);return t(n,i)}}(parseInt)}var rr=function(){if(typeof Symbol!=="function"){return false}try{parseInt(Object(Symbol.iterator));return true}catch(t){}try{parseInt(Symbol.iterator);return true}catch(t){}return false}();if(rr){var nr=Symbol.prototype.valueOf;parseInt=function(t){return function parseInt(e,r){if(this instanceof parseInt){new t}var n=typeof e==="symbol";if(!n&&e&&typeof e==="object"){try{nr.call(e);n=true}catch(i){}}if(n){""+e}var a=Ve(String(e));var o=u(r)||(er.test(a)?16:10);return t(a,o)}}(parseInt)}if(1/parseFloat("-0")!==-Infinity){parseFloat=function(t){return function parseFloat(e){var r=Ve(String(e));var n=t(r);return n===0&&ut(r,0,1)==="-"?-0:n}}(parseFloat)}if(String(new RangeError("test"))!=="RangeError: test"){var ir=function toString(){if(typeof this==="undefined"||this===null){throw new TypeError("can't convert "+this+" to object")}var t=this.name;if(typeof t==="undefined"){t="Error"}else if(typeof t!=="string"){t=o(t)}var e=this.message;if(typeof e==="undefined"){e=""}else if(typeof e!=="string"){e=o(e)}if(!t){return e}if(!e){return t}return t+": "+e};Error.prototype.toString=ir}if(H){var ar=function(t,e){if(vt(t,e)){var r=Object.getOwnPropertyDescriptor(t,e);if(r.configurable){r.enumerable=false;Object.defineProperty(t,e,r)}}};ar(Error.prototype,"message");if(Error.prototype.message!==""){Error.prototype.message=""}ar(Error.prototype,"name")}if(String(/a/gim)!=="/a/gim"){var or=function toString(){var t="/"+this.source+"/";if(this.global){t+="g"}if(this.ignoreCase){t+="i"}if(this.multiline){t+="m"}return t};RegExp.prototype.toString=or}});
//# sourceMappingURL=es5-shim.map

/*!
 * https://github.com/es-shims/es5-shim
 * @license es5-shim Copyright 2009-2020 by contributors, MIT License
 * see https://github.com/es-shims/es5-shim/blob/master/LICENSE
 */
(function(e,t){"use strict";if(typeof define==="function"&&define.amd){define(t)}else if(typeof exports==="object"){module.exports=t()}else{e.returnExports=t()}})(this,function(){var e=Function.call;var t=Object.prototype;var r=e.bind(t.hasOwnProperty);var n=e.bind(t.propertyIsEnumerable);var o=e.bind(t.toString);var i;var c;var f;var a;var l=r(t,"__defineGetter__");if(l){i=e.bind(t.__defineGetter__);c=e.bind(t.__defineSetter__);f=e.bind(t.__lookupGetter__);a=e.bind(t.__lookupSetter__)}var u=function isPrimitive(e){return e==null||typeof e!=="object"&&typeof e!=="function"};if(!Object.getPrototypeOf){Object.getPrototypeOf=function getPrototypeOf(e){var r=e.__proto__;if(r||r==null){return r}else if(o(e.constructor)==="[object Function]"){return e.constructor.prototype}else if(e instanceof Object){return t}return null}}if(Object.defineProperty){var p=function doesGetOwnPropertyDescriptorWork(e){try{e.sentinel=0;return Object.getOwnPropertyDescriptor(e,"sentinel").value===0}catch(t){return false}};var s=p({});var b=typeof document==="undefined"||p(document.createElement("div"));if(!b||!s){var O=Object.getOwnPropertyDescriptor}}if(!Object.getOwnPropertyDescriptor||O){var d="Object.getOwnPropertyDescriptor called on a non-object: ";Object.getOwnPropertyDescriptor=function getOwnPropertyDescriptor(e,o){if(u(e)){throw new TypeError(d+e)}if(O){try{return O.call(Object,e,o)}catch(i){}}var c;if(!r(e,o)){return c}c={enumerable:n(e,o),configurable:true};if(l){var p=e.__proto__;var s=e!==t;if(s){e.__proto__=t}var b=f(e,o);var y=a(e,o);if(s){e.__proto__=p}if(b||y){if(b){c.get=b}if(y){c.set=y}return c}}c.value=e[o];c.writable=true;return c}}if(!Object.getOwnPropertyNames){Object.getOwnPropertyNames=function getOwnPropertyNames(e){return Object.keys(e)}}if(!Object.create){var y;var j=!({__proto__:null}instanceof Object);var v=function shouldUseActiveX(){if(!document.domain){return false}try{return!!new ActiveXObject("htmlfile")}catch(e){return false}};var _=function getEmptyViaActiveX(){var e;var t;t=new ActiveXObject("htmlfile");var r="script";t.write("<"+r+"></"+r+">");t.close();e=t.parentWindow.Object.prototype;t=null;return e};var w=function getEmptyViaIFrame(){var e=document.createElement("iframe");var t=document.body||document.documentElement;var r;e.style.display="none";t.appendChild(e);e.src="javascript:";r=e.contentWindow.Object.prototype;t.removeChild(e);e=null;return r};if(j||typeof document==="undefined"){y=function(){return{__proto__:null}}}else{y=function(){var e=v()?_():w();delete e.constructor;delete e.hasOwnProperty;delete e.propertyIsEnumerable;delete e.isPrototypeOf;delete e.toLocaleString;delete e.toString;delete e.valueOf;var t=function Empty(){};t.prototype=e;y=function(){return new t};return new t}}Object.create=function create(e,t){var r;var n=function Type(){};if(e===null){r=y()}else if(u(e)){throw new TypeError("Object prototype may only be an Object or null")}else{n.prototype=e;r=new n;r.__proto__=e}if(t!==void 0){Object.defineProperties(r,t)}return r}}var m=function doesDefinePropertyWork(e){try{Object.defineProperty(e,"sentinel",{});return"sentinel"in e}catch(t){return false}};if(Object.defineProperty){var P=m({});var E=typeof document==="undefined"||m(document.createElement("div"));if(!P||!E){var h=Object.defineProperty,g=Object.defineProperties}}if(!Object.defineProperty||h){var z="Property description must be an object: ";var T="Object.defineProperty called on non-object: ";var x="getters & setters can not be defined on this javascript engine";Object.defineProperty=function defineProperty(e,r,n){if(u(e)){throw new TypeError(T+e)}if(u(n)){throw new TypeError(z+n)}if(h){try{return h.call(Object,e,r,n)}catch(o){}}if("value"in n){if(l&&(f(e,r)||a(e,r))){var p=e.__proto__;e.__proto__=t;delete e[r];e[r]=n.value;e.__proto__=p}else{e[r]=n.value}}else{var s="get"in n;var b="set"in n;if(!l&&(s||b)){throw new TypeError(x)}if(s){i(e,r,n.get)}if(b){c(e,r,n.set)}}return e}}if(!Object.defineProperties||g){Object.defineProperties=function defineProperties(e,t){if(g){try{return g.call(Object,e,t)}catch(r){}}Object.keys(t).forEach(function(r){if(r!=="__proto__"){Object.defineProperty(e,r,t[r])}});return e}}if(!Object.seal){Object.seal=function seal(e){if(Object(e)!==e){throw new TypeError("Object.seal can only be called on Objects.")}return e}}if(!Object.freeze){Object.freeze=function freeze(e){if(Object(e)!==e){throw new TypeError("Object.freeze can only be called on Objects.")}return e}}try{Object.freeze(function(){})}catch(S){Object.freeze=function(e){return function freeze(t){if(typeof t==="function"){return t}return e(t)}}(Object.freeze)}if(!Object.preventExtensions){Object.preventExtensions=function preventExtensions(e){if(Object(e)!==e){throw new TypeError("Object.preventExtensions can only be called on Objects.")}return e}}if(!Object.isSealed){Object.isSealed=function isSealed(e){if(Object(e)!==e){throw new TypeError("Object.isSealed can only be called on Objects.")}return false}}if(!Object.isFrozen){Object.isFrozen=function isFrozen(e){if(Object(e)!==e){throw new TypeError("Object.isFrozen can only be called on Objects.")}return false}}if(!Object.isExtensible){Object.isExtensible=function isExtensible(e){if(Object(e)!==e){throw new TypeError("Object.isExtensible can only be called on Objects.")}var t="";while(r(e,t)){t+="?"}e[t]=true;var n=r(e,t);delete e[t];return n}}});
//# sourceMappingURL=es5-sham.map

/*
 Copyright (c) 2010, Linden Research, Inc.
 Copyright (c) 2014, Joshua Bell

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 $/LicenseInfo$
 */

// Original can be found at:
//   https://bitbucket.org/lindenlab/llsd
// Modifications by Joshua Bell inexorabletash@gmail.com
//   https://github.com/inexorabletash/polyfill

// ES3/ES5 implementation of the Krhonos Typed Array Specification
//   Ref: http://www.khronos.org/registry/typedarray/specs/latest/
//   Date: 2011-02-01
//
// Variations:
//  * Allows typed_array.get/set() as alias for subscripts (typed_array[])
//  * Gradually migrating structure from Khronos spec to ES2015 spec
//
// Caveats:
//  * Beyond 10000 or so entries, polyfilled array accessors (ta[0],
//    etc) become memory-prohibitive, so array creation will fail. Set
//    self.TYPED_ARRAY_POLYFILL_NO_ARRAY_ACCESSORS=true to disable
//    creation of accessors. Your code will need to use the
//    non-standard get()/set() instead, and will need to add those to
//    native arrays for interop.
(function(global) {
  'use strict';
  var undefined = (void 0); // Paranoia

  // Beyond this value, index getters/setters (i.e. array[0], array[1]) are so slow to
  // create, and consume so much memory, that the browser appears frozen.
  var MAX_ARRAY_LENGTH = 1e5;

  // Approximations of internal ECMAScript conversion functions
  function Type(v) {
    switch(typeof v) {
    case 'undefined': return 'undefined';
    case 'boolean': return 'boolean';
    case 'number': return 'number';
    case 'string': return 'string';
    default: return v === null ? 'null' : 'object';
    }
  }

  // Class returns internal [[Class]] property, used to avoid cross-frame instanceof issues:
  function Class(v) { return Object.prototype.toString.call(v).replace(/^\[object *|\]$/g, ''); }
  function IsCallable(o) { return typeof o === 'function'; }
  function ToObject(v) {
    if (v === null || v === undefined) throw TypeError();
    return Object(v);
  }
  function ToInt32(v) { return v >> 0; }
  function ToUint32(v) { return v >>> 0; }

  // Snapshot intrinsics
  var LN2 = Math.LN2,
      abs = Math.abs,
      floor = Math.floor,
      log = Math.log,
      max = Math.max,
      min = Math.min,
      pow = Math.pow,
      round = Math.round;

  // emulate ES5 getter/setter API using legacy APIs
  // http://blogs.msdn.com/b/ie/archive/2010/09/07/transitioning-existing-code-to-the-es5-getter-setter-apis.aspx
  // (second clause tests for Object.defineProperty() in IE<9 that only supports extending DOM prototypes, but
  // note that IE<9 does not support __defineGetter__ or __defineSetter__ so it just renders the method harmless)

  (function() {
    var orig = Object.defineProperty;
    var dom_only = !(function(){try{return Object.defineProperty({},'x',{});}catch(_){return false;}}());

    if (!orig || dom_only) {
      Object.defineProperty = function (o, prop, desc) {
        // In IE8 try built-in implementation for defining properties on DOM prototypes.
        if (orig)
          try { return orig(o, prop, desc); } catch (_) {}
        if (o !== Object(o))
          throw TypeError('Object.defineProperty called on non-object');
        if (Object.prototype.__defineGetter__ && ('get' in desc))
          Object.prototype.__defineGetter__.call(o, prop, desc.get);
        if (Object.prototype.__defineSetter__ && ('set' in desc))
          Object.prototype.__defineSetter__.call(o, prop, desc.set);
        if ('value' in desc)
          o[prop] = desc.value;
        return o;
      };
    }
  }());

  // ES5: Make obj[index] an alias for obj._getter(index)/obj._setter(index, value)
  // for index in 0 ... obj.length
  function makeArrayAccessors(obj) {
    if ('TYPED_ARRAY_POLYFILL_NO_ARRAY_ACCESSORS' in global)
      return;

    if (obj.length > MAX_ARRAY_LENGTH) throw RangeError('Array too large for polyfill');

    function makeArrayAccessor(index) {
      Object.defineProperty(obj, index, {
        'get': function() { return obj._getter(index); },
        'set': function(v) { obj._setter(index, v); },
        enumerable: true,
        configurable: false
      });
    }

    var i;
    for (i = 0; i < obj.length; i += 1) {
      makeArrayAccessor(i);
    }
  }

  // Internal conversion functions:
  //    pack<Type>()   - take a number (interpreted as Type), output a byte array
  //    unpack<Type>() - take a byte array, output a Type-like number

  function as_signed(value, bits) { var s = 32 - bits; return (value << s) >> s; }
  function as_unsigned(value, bits) { var s = 32 - bits; return (value << s) >>> s; }

  function packI8(n) { return [n & 0xff]; }
  function unpackI8(bytes) { return as_signed(bytes[0], 8); }

  function packU8(n) { return [n & 0xff]; }
  function unpackU8(bytes) { return as_unsigned(bytes[0], 8); }

  function packU8Clamped(n) { n = round(Number(n)); return [n < 0 ? 0 : n > 0xff ? 0xff : n & 0xff]; }

  function packI16(n) { return [n & 0xff, (n >> 8) & 0xff]; }
  function unpackI16(bytes) { return as_signed(bytes[1] << 8 | bytes[0], 16); }

  function packU16(n) { return [n & 0xff, (n >> 8) & 0xff]; }
  function unpackU16(bytes) { return as_unsigned(bytes[1] << 8 | bytes[0], 16); }

  function packI32(n) { return [n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff]; }
  function unpackI32(bytes) { return as_signed(bytes[3] << 24 | bytes[2] << 16 | bytes[1] << 8 | bytes[0], 32); }

  function packU32(n) { return [n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff]; }
  function unpackU32(bytes) { return as_unsigned(bytes[3] << 24 | bytes[2] << 16 | bytes[1] << 8 | bytes[0], 32); }

  function packIEEE754(v, ebits, fbits) {

    var bias = (1 << (ebits - 1)) - 1;

    function roundToEven(n) {
      var w = floor(n), f = n - w;
      if (f < 0.5)
        return w;
      if (f > 0.5)
        return w + 1;
      return w % 2 ? w + 1 : w;
    }

    // Compute sign, exponent, fraction
    var s, e, f;
    if (v !== v) {
      // NaN
      // http://dev.w3.org/2006/webapi/WebIDL/#es-type-mapping
      e = (1 << ebits) - 1; f = pow(2, fbits - 1); s = 0;
    } else if (v === Infinity || v === -Infinity) {
      e = (1 << ebits) - 1; f = 0; s = (v < 0) ? 1 : 0;
    } else if (v === 0) {
      e = 0; f = 0; s = (1 / v === -Infinity) ? 1 : 0;
    } else {
      s = v < 0;
      v = abs(v);

      if (v >= pow(2, 1 - bias)) {
        // Normalized
        e = min(floor(log(v) / LN2), 1023);
        var significand = v / pow(2, e);
        if (significand < 1) {
          e -= 1;
          significand *= 2;
        }
        if (significand >= 2) {
          e += 1;
          significand /= 2;
        }
        var d = pow(2, fbits);
        f = roundToEven(significand * d) - d;
        e += bias;
        if (f / d >= 1) {
          e += 1;
          f = 0;
        }
        if (e > 2 * bias) {
          // Overflow
          e = (1 << ebits) - 1;
          f = 0;
        }
      } else {
        // Denormalized
        e = 0;
        f = roundToEven(v / pow(2, 1 - bias - fbits));
      }
    }

    // Pack sign, exponent, fraction
    var bits = [], i;
    for (i = fbits; i; i -= 1) { bits.push(f % 2 ? 1 : 0); f = floor(f / 2); }
    for (i = ebits; i; i -= 1) { bits.push(e % 2 ? 1 : 0); e = floor(e / 2); }
    bits.push(s ? 1 : 0);
    bits.reverse();
    var str = bits.join('');

    // Bits to bytes
    var bytes = [];
    while (str.length) {
      bytes.unshift(parseInt(str.substring(0, 8), 2));
      str = str.substring(8);
    }
    return bytes;
  }

  function unpackIEEE754(bytes, ebits, fbits) {
    // Bytes to bits
    var bits = [], i, j, b, str,
        bias, s, e, f;

    for (i = 0; i < bytes.length; ++i) {
      b = bytes[i];
      for (j = 8; j; j -= 1) {
        bits.push(b % 2 ? 1 : 0); b = b >> 1;
      }
    }
    bits.reverse();
    str = bits.join('');

    // Unpack sign, exponent, fraction
    bias = (1 << (ebits - 1)) - 1;
    s = parseInt(str.substring(0, 1), 2) ? -1 : 1;
    e = parseInt(str.substring(1, 1 + ebits), 2);
    f = parseInt(str.substring(1 + ebits), 2);

    // Produce number
    if (e === (1 << ebits) - 1) {
      return f !== 0 ? NaN : s * Infinity;
    } else if (e > 0) {
      // Normalized
      return s * pow(2, e - bias) * (1 + f / pow(2, fbits));
    } else if (f !== 0) {
      // Denormalized
      return s * pow(2, -(bias - 1)) * (f / pow(2, fbits));
    } else {
      return s < 0 ? -0 : 0;
    }
  }

  function unpackF64(b) { return unpackIEEE754(b, 11, 52); }
  function packF64(v) { return packIEEE754(v, 11, 52); }
  function unpackF32(b) { return unpackIEEE754(b, 8, 23); }
  function packF32(v) { return packIEEE754(v, 8, 23); }

  //
  // 3 The ArrayBuffer Type
  //

  (function() {

    function ArrayBuffer(length) {
      length = ToInt32(length);
      if (length < 0) throw RangeError('ArrayBuffer size is not a small enough positive integer.');
      Object.defineProperty(this, 'byteLength', {value: length});
      Object.defineProperty(this, '_bytes', {value: Array(length)});

      for (var i = 0; i < length; i += 1)
        this._bytes[i] = 0;
    }

    global.ArrayBuffer = global.ArrayBuffer || ArrayBuffer;

    //
    // 5 The Typed Array View Types
    //

    function $TypedArray$() {

      // %TypedArray% ( length )
      if (!arguments.length || typeof arguments[0] !== 'object') {
        return (function(length) {
          length = ToInt32(length);
          if (length < 0) throw RangeError('length is not a small enough positive integer.');
          Object.defineProperty(this, 'length', {value: length});
          Object.defineProperty(this, 'byteLength', {value: length * this.BYTES_PER_ELEMENT});
          Object.defineProperty(this, 'buffer', {value: new ArrayBuffer(this.byteLength)});
          Object.defineProperty(this, 'byteOffset', {value: 0});

         }).apply(this, arguments);
      }

      // %TypedArray% ( typedArray )
      if (arguments.length >= 1 &&
          Type(arguments[0]) === 'object' &&
          arguments[0] instanceof $TypedArray$) {
        return (function(typedArray){
          if (this.constructor !== typedArray.constructor) throw TypeError();

          var byteLength = typedArray.length * this.BYTES_PER_ELEMENT;
          Object.defineProperty(this, 'buffer', {value: new ArrayBuffer(byteLength)});
          Object.defineProperty(this, 'byteLength', {value: byteLength});
          Object.defineProperty(this, 'byteOffset', {value: 0});
          Object.defineProperty(this, 'length', {value: typedArray.length});

          for (var i = 0; i < this.length; i += 1)
            this._setter(i, typedArray._getter(i));

        }).apply(this, arguments);
      }

      // %TypedArray% ( array )
      if (arguments.length >= 1 &&
          Type(arguments[0]) === 'object' &&
          !(arguments[0] instanceof $TypedArray$) &&
          !(arguments[0] instanceof ArrayBuffer || Class(arguments[0]) === 'ArrayBuffer')) {
        return (function(array) {

          var byteLength = array.length * this.BYTES_PER_ELEMENT;
          Object.defineProperty(this, 'buffer', {value: new ArrayBuffer(byteLength)});
          Object.defineProperty(this, 'byteLength', {value: byteLength});
          Object.defineProperty(this, 'byteOffset', {value: 0});
          Object.defineProperty(this, 'length', {value: array.length});

          for (var i = 0; i < this.length; i += 1) {
            var s = array[i];
            this._setter(i, Number(s));
          }
        }).apply(this, arguments);
      }

      // %TypedArray% ( buffer, byteOffset=0, length=undefined )
      if (arguments.length >= 1 &&
          Type(arguments[0]) === 'object' &&
          (arguments[0] instanceof ArrayBuffer || Class(arguments[0]) === 'ArrayBuffer')) {
        return (function(buffer, byteOffset, length) {

          byteOffset = ToUint32(byteOffset);
          if (byteOffset > buffer.byteLength)
            throw RangeError('byteOffset out of range');

          // The given byteOffset must be a multiple of the element
          // size of the specific type, otherwise an exception is raised.
          if (byteOffset % this.BYTES_PER_ELEMENT)
            throw RangeError('buffer length minus the byteOffset is not a multiple of the element size.');

          if (length === undefined) {
            var byteLength = buffer.byteLength - byteOffset;
            if (byteLength % this.BYTES_PER_ELEMENT)
              throw RangeError('length of buffer minus byteOffset not a multiple of the element size');
            length = byteLength / this.BYTES_PER_ELEMENT;

          } else {
            length = ToUint32(length);
            byteLength = length * this.BYTES_PER_ELEMENT;
          }

          if ((byteOffset + byteLength) > buffer.byteLength)
            throw RangeError('byteOffset and length reference an area beyond the end of the buffer');

          Object.defineProperty(this, 'buffer', {value: buffer});
          Object.defineProperty(this, 'byteLength', {value: byteLength});
          Object.defineProperty(this, 'byteOffset', {value: byteOffset});
          Object.defineProperty(this, 'length', {value: length});

        }).apply(this, arguments);
      }

      // %TypedArray% ( all other argument combinations )
      throw TypeError();
    }

    // Properties of the %TypedArray Instrinsic Object

    // %TypedArray%.from ( source , mapfn=undefined, thisArg=undefined )
    Object.defineProperty($TypedArray$, 'from', {value: function(iterable) {
      return new this(iterable);
    }});

    // %TypedArray%.of ( ...items )
    Object.defineProperty($TypedArray$, 'of', {value: function(/*...items*/) {
      return new this(arguments);
    }});

    // %TypedArray%.prototype
    var $TypedArrayPrototype$ = {};
    $TypedArray$.prototype = $TypedArrayPrototype$;

    // WebIDL: getter type (unsigned long index);
    Object.defineProperty($TypedArray$.prototype, '_getter', {value: function(index) {
      if (arguments.length < 1) throw SyntaxError('Not enough arguments');

      index = ToUint32(index);
      if (index >= this.length)
        return undefined;

      var bytes = [], i, o;
      for (i = 0, o = this.byteOffset + index * this.BYTES_PER_ELEMENT;
           i < this.BYTES_PER_ELEMENT;
           i += 1, o += 1) {
        bytes.push(this.buffer._bytes[o]);
      }
      return this._unpack(bytes);
    }});

    // NONSTANDARD: convenience alias for getter: type get(unsigned long index);
    Object.defineProperty($TypedArray$.prototype, 'get', {value: $TypedArray$.prototype._getter});

    // WebIDL: setter void (unsigned long index, type value);
    Object.defineProperty($TypedArray$.prototype, '_setter', {value: function(index, value) {
      if (arguments.length < 2) throw SyntaxError('Not enough arguments');

      index = ToUint32(index);
      if (index >= this.length)
        return;

      var bytes = this._pack(value), i, o;
      for (i = 0, o = this.byteOffset + index * this.BYTES_PER_ELEMENT;
           i < this.BYTES_PER_ELEMENT;
           i += 1, o += 1) {
        this.buffer._bytes[o] = bytes[i];
      }
    }});

    // get %TypedArray%.prototype.buffer
    // get %TypedArray%.prototype.byteLength
    // get %TypedArray%.prototype.byteOffset
    // -- applied directly to the object in the constructor

    // %TypedArray%.prototype.constructor
    Object.defineProperty($TypedArray$.prototype, 'constructor', {value: $TypedArray$});

    // %TypedArray%.prototype.copyWithin (target, start, end = this.length )
    Object.defineProperty($TypedArray$.prototype, 'copyWithin', {value: function(target, start) {
      var end = arguments[2];

      var o = ToObject(this);
      var lenVal = o.length;
      var len = ToUint32(lenVal);
      len = max(len, 0);
      var relativeTarget = ToInt32(target);
      var to;
      if (relativeTarget < 0)
        to = max(len + relativeTarget, 0);
      else
        to = min(relativeTarget, len);
      var relativeStart = ToInt32(start);
      var from;
      if (relativeStart < 0)
        from = max(len + relativeStart, 0);
      else
        from = min(relativeStart, len);
      var relativeEnd;
      if (end === undefined)
        relativeEnd = len;
      else
        relativeEnd = ToInt32(end);
      var final;
      if (relativeEnd < 0)
        final = max(len + relativeEnd, 0);
      else
        final = min(relativeEnd, len);
      var count = min(final - from, len - to);
      var direction;
      if (from < to && to < from + count) {
        direction = -1;
        from = from + count - 1;
        to = to + count - 1;
      } else {
        direction = 1;
      }
      while (count > 0) {
        o._setter(to, o._getter(from));
        from = from + direction;
        to = to + direction;
        count = count - 1;
      }
      return o;
    }});

    // %TypedArray%.prototype.entries ( )
    // -- defined in es6.js to shim browsers w/ native TypedArrays

    // %TypedArray%.prototype.every ( callbackfn, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'every', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      var thisArg = arguments[1];
      for (var i = 0; i < len; i++) {
        if (!callbackfn.call(thisArg, t._getter(i), i, t))
          return false;
      }
      return true;
    }});

    // %TypedArray%.prototype.fill (value, start = 0, end = this.length )
    Object.defineProperty($TypedArray$.prototype, 'fill', {value: function(value) {
      var start = arguments[1],
          end = arguments[2];

      var o = ToObject(this);
      var lenVal = o.length;
      var len = ToUint32(lenVal);
      len = max(len, 0);
      var relativeStart = ToInt32(start);
      var k;
      if (relativeStart < 0)
        k = max((len + relativeStart), 0);
      else
        k = min(relativeStart, len);
      var relativeEnd;
      if (end === undefined)
        relativeEnd = len;
      else
        relativeEnd = ToInt32(end);
      var final;
      if (relativeEnd < 0)
        final = max((len + relativeEnd), 0);
      else
        final = min(relativeEnd, len);
      while (k < final) {
        o._setter(k, value);
        k += 1;
      }
      return o;
    }});

    // %TypedArray%.prototype.filter ( callbackfn, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'filter', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      var res = [];
      var thisp = arguments[1];
      for (var i = 0; i < len; i++) {
        var val = t._getter(i); // in case fun mutates this
        if (callbackfn.call(thisp, val, i, t))
          res.push(val);
      }
      return new this.constructor(res);
    }});

    // %TypedArray%.prototype.find (predicate, thisArg = undefined)
    Object.defineProperty($TypedArray$.prototype, 'find', {value: function(predicate) {
      var o = ToObject(this);
      var lenValue = o.length;
      var len = ToUint32(lenValue);
      if (!IsCallable(predicate)) throw TypeError();
      var t = arguments.length > 1 ? arguments[1] : undefined;
      var k = 0;
      while (k < len) {
        var kValue = o._getter(k);
        var testResult = predicate.call(t, kValue, k, o);
        if (Boolean(testResult))
          return kValue;
        ++k;
      }
      return undefined;
    }});

    // %TypedArray%.prototype.findIndex ( predicate, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'findIndex', {value: function(predicate) {
      var o = ToObject(this);
      var lenValue = o.length;
      var len = ToUint32(lenValue);
      if (!IsCallable(predicate)) throw TypeError();
      var t = arguments.length > 1 ? arguments[1] : undefined;
      var k = 0;
      while (k < len) {
        var kValue = o._getter(k);
        var testResult = predicate.call(t, kValue, k, o);
        if (Boolean(testResult))
          return k;
        ++k;
      }
      return -1;
    }});

    // %TypedArray%.prototype.forEach ( callbackfn, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'forEach', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      var thisp = arguments[1];
      for (var i = 0; i < len; i++)
        callbackfn.call(thisp, t._getter(i), i, t);
    }});

    // %TypedArray%.prototype.indexOf (searchElement, fromIndex = 0 )
    Object.defineProperty($TypedArray$.prototype, 'indexOf', {value: function(searchElement) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (len === 0) return -1;
      var n = 0;
      if (arguments.length > 0) {
        n = Number(arguments[1]);
        if (n !== n) {
          n = 0;
        } else if (n !== 0 && n !== (1 / 0) && n !== -(1 / 0)) {
          n = (n > 0 || -1) * floor(abs(n));
        }
      }
      if (n >= len) return -1;
      var k = n >= 0 ? n : max(len - abs(n), 0);
      for (; k < len; k++) {
        if (t._getter(k) === searchElement) {
          return k;
        }
      }
      return -1;
    }});

    // %TypedArray%.prototype.join ( separator )
    Object.defineProperty($TypedArray$.prototype, 'join', {value: function(separator) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      var tmp = Array(len);
      for (var i = 0; i < len; ++i)
        tmp[i] = t._getter(i);
      return tmp.join(separator === undefined ? ',' : separator); // Hack for IE7
    }});

    // %TypedArray%.prototype.keys ( )
    // -- defined in es6.js to shim browsers w/ native TypedArrays

    // %TypedArray%.prototype.lastIndexOf ( searchElement, fromIndex = this.length-1 )
    Object.defineProperty($TypedArray$.prototype, 'lastIndexOf', {value: function(searchElement) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (len === 0) return -1;
      var n = len;
      if (arguments.length > 1) {
        n = Number(arguments[1]);
        if (n !== n) {
          n = 0;
        } else if (n !== 0 && n !== (1 / 0) && n !== -(1 / 0)) {
          n = (n > 0 || -1) * floor(abs(n));
        }
      }
      var k = n >= 0 ? min(n, len - 1) : len - abs(n);
      for (; k >= 0; k--) {
        if (t._getter(k) === searchElement)
          return k;
      }
      return -1;
    }});

    // get %TypedArray%.prototype.length
    // -- applied directly to the object in the constructor

    // %TypedArray%.prototype.map ( callbackfn, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'map', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      var res = []; res.length = len;
      var thisp = arguments[1];
      for (var i = 0; i < len; i++)
        res[i] = callbackfn.call(thisp, t._getter(i), i, t);
      return new this.constructor(res);
    }});

    // %TypedArray%.prototype.reduce ( callbackfn [, initialValue] )
    Object.defineProperty($TypedArray$.prototype, 'reduce', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      // no value to return if no initial value and an empty array
      if (len === 0 && arguments.length === 1) throw TypeError();
      var k = 0;
      var accumulator;
      if (arguments.length >= 2) {
        accumulator = arguments[1];
      } else {
        accumulator = t._getter(k++);
      }
      while (k < len) {
        accumulator = callbackfn.call(undefined, accumulator, t._getter(k), k, t);
        k++;
      }
      return accumulator;
    }});

    // %TypedArray%.prototype.reduceRight ( callbackfn [, initialValue] )
    Object.defineProperty($TypedArray$.prototype, 'reduceRight', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      // no value to return if no initial value, empty array
      if (len === 0 && arguments.length === 1) throw TypeError();
      var k = len - 1;
      var accumulator;
      if (arguments.length >= 2) {
        accumulator = arguments[1];
      } else {
        accumulator = t._getter(k--);
      }
      while (k >= 0) {
        accumulator = callbackfn.call(undefined, accumulator, t._getter(k), k, t);
        k--;
      }
      return accumulator;
    }});

    // %TypedArray%.prototype.reverse ( )
    Object.defineProperty($TypedArray$.prototype, 'reverse', {value: function() {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      var half = floor(len / 2);
      for (var i = 0, j = len - 1; i < half; ++i, --j) {
        var tmp = t._getter(i);
        t._setter(i, t._getter(j));
        t._setter(j, tmp);
      }
      return t;
    }});

    // %TypedArray%.prototype.set(array, offset = 0 )
    // %TypedArray%.prototype.set(typedArray, offset = 0 )
    // WebIDL: void set(TypedArray array, optional unsigned long offset);
    // WebIDL: void set(sequence<type> array, optional unsigned long offset);
    Object.defineProperty($TypedArray$.prototype, 'set', {value: function(index, value) {
      if (arguments.length < 1) throw SyntaxError('Not enough arguments');
      var array, sequence, offset, len,
          i, s, d,
          byteOffset, byteLength, tmp;

      if (typeof arguments[0] === 'object' && arguments[0].constructor === this.constructor) {
        // void set(TypedArray array, optional unsigned long offset);
        array = arguments[0];
        offset = ToUint32(arguments[1]);

        if (offset + array.length > this.length) {
          throw RangeError('Offset plus length of array is out of range');
        }

        byteOffset = this.byteOffset + offset * this.BYTES_PER_ELEMENT;
        byteLength = array.length * this.BYTES_PER_ELEMENT;

        if (array.buffer === this.buffer) {
          tmp = [];
          for (i = 0, s = array.byteOffset; i < byteLength; i += 1, s += 1) {
            tmp[i] = array.buffer._bytes[s];
          }
          for (i = 0, d = byteOffset; i < byteLength; i += 1, d += 1) {
            this.buffer._bytes[d] = tmp[i];
          }
        } else {
          for (i = 0, s = array.byteOffset, d = byteOffset;
               i < byteLength; i += 1, s += 1, d += 1) {
            this.buffer._bytes[d] = array.buffer._bytes[s];
          }
        }
      } else if (typeof arguments[0] === 'object' && typeof arguments[0].length !== 'undefined') {
        // void set(sequence<type> array, optional unsigned long offset);
        sequence = arguments[0];
        len = ToUint32(sequence.length);
        offset = ToUint32(arguments[1]);

        if (offset + len > this.length) {
          throw RangeError('Offset plus length of array is out of range');
        }

        for (i = 0; i < len; i += 1) {
          s = sequence[i];
          this._setter(offset + i, Number(s));
        }
      } else {
        throw TypeError('Unexpected argument type(s)');
      }
    }});

    // %TypedArray%.prototype.slice ( start, end )
    Object.defineProperty($TypedArray$.prototype, 'slice', {value: function(start, end) {
      var o = ToObject(this);
      var lenVal = o.length;
      var len = ToUint32(lenVal);
      var relativeStart = ToInt32(start);
      var k = (relativeStart < 0) ? max(len + relativeStart, 0) : min(relativeStart, len);
      var relativeEnd = (end === undefined) ? len : ToInt32(end);
      var final = (relativeEnd < 0) ? max(len + relativeEnd, 0) : min(relativeEnd, len);
      var count = final - k;
      var c = o.constructor;
      var a = new c(count);
      var n = 0;
      while (k < final) {
        var kValue = o._getter(k);
        a._setter(n, kValue);
        ++k;
        ++n;
      }
      return a;
    }});

    // %TypedArray%.prototype.some ( callbackfn, thisArg = undefined )
    Object.defineProperty($TypedArray$.prototype, 'some', {value: function(callbackfn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      if (!IsCallable(callbackfn)) throw TypeError();
      var thisp = arguments[1];
      for (var i = 0; i < len; i++) {
        if (callbackfn.call(thisp, t._getter(i), i, t)) {
          return true;
        }
      }
      return false;
    }});

    // %TypedArray%.prototype.sort ( comparefn )
    Object.defineProperty($TypedArray$.prototype, 'sort', {value: function(comparefn) {
      if (this === undefined || this === null) throw TypeError();
      var t = Object(this);
      var len = ToUint32(t.length);
      var tmp = Array(len);
      for (var i = 0; i < len; ++i)
        tmp[i] = t._getter(i);
      function sortCompare(x, y) {
        if (x !== x && y !== y) return +0;
        if (x !== x) return 1;
        if (y !== y) return -1;
        if (comparefn !== undefined) {
          return comparefn(x, y);
        }
        if (x < y) return -1;
        if (x > y) return 1;
        return +0;
      }
      tmp.sort(sortCompare);
      for (i = 0; i < len; ++i)
        t._setter(i, tmp[i]);
      return t;
    }});

    // %TypedArray%.prototype.subarray(begin = 0, end = this.length )
    // WebIDL: TypedArray subarray(long begin, optional long end);
    Object.defineProperty($TypedArray$.prototype, 'subarray', {value: function(start, end) {
      function clamp(v, min, max) { return v < min ? min : v > max ? max : v; }

      start = ToInt32(start);
      end = ToInt32(end);

      if (arguments.length < 1) { start = 0; }
      if (arguments.length < 2) { end = this.length; }

      if (start < 0) { start = this.length + start; }
      if (end < 0) { end = this.length + end; }

      start = clamp(start, 0, this.length);
      end = clamp(end, 0, this.length);

      var len = end - start;
      if (len < 0) {
        len = 0;
      }

      return new this.constructor(
        this.buffer, this.byteOffset + start * this.BYTES_PER_ELEMENT, len);
    }});

    // %TypedArray%.prototype.toLocaleString ( )
    // %TypedArray%.prototype.toString ( )
    // %TypedArray%.prototype.values ( )
    // %TypedArray%.prototype [ @@iterator ] ( )
    // get %TypedArray%.prototype [ @@toStringTag ]
    // -- defined in es6.js to shim browsers w/ native TypedArrays

    function makeTypedArray(elementSize, pack, unpack) {
      // Each TypedArray type requires a distinct constructor instance with
      // identical logic, which this produces.
      var TypedArray = function() {
        Object.defineProperty(this, 'constructor', {value: TypedArray});
        $TypedArray$.apply(this, arguments);
        makeArrayAccessors(this);
      };
      if ('__proto__' in TypedArray) {
        TypedArray.__proto__ = $TypedArray$;
      } else {
        TypedArray.from = $TypedArray$.from;
        TypedArray.of = $TypedArray$.of;
      }

      TypedArray.BYTES_PER_ELEMENT = elementSize;

      var TypedArrayPrototype = function() {};
      TypedArrayPrototype.prototype = $TypedArrayPrototype$;

      TypedArray.prototype = new TypedArrayPrototype();

      Object.defineProperty(TypedArray.prototype, 'BYTES_PER_ELEMENT', {value: elementSize});
      Object.defineProperty(TypedArray.prototype, '_pack', {value: pack});
      Object.defineProperty(TypedArray.prototype, '_unpack', {value: unpack});

      return TypedArray;
    }

    var Int8Array = makeTypedArray(1, packI8, unpackI8);
    var Uint8Array = makeTypedArray(1, packU8, unpackU8);
    var Uint8ClampedArray = makeTypedArray(1, packU8Clamped, unpackU8);
    var Int16Array = makeTypedArray(2, packI16, unpackI16);
    var Uint16Array = makeTypedArray(2, packU16, unpackU16);
    var Int32Array = makeTypedArray(4, packI32, unpackI32);
    var Uint32Array = makeTypedArray(4, packU32, unpackU32);
    var Float32Array = makeTypedArray(4, packF32, unpackF32);
    var Float64Array = makeTypedArray(8, packF64, unpackF64);

    global.Int8Array = global.Int8Array || Int8Array;
    global.Uint8Array = global.Uint8Array || Uint8Array;
    global.Uint8ClampedArray = global.Uint8ClampedArray || Uint8ClampedArray;
    global.Int16Array = global.Int16Array || Int16Array;
    global.Uint16Array = global.Uint16Array || Uint16Array;
    global.Int32Array = global.Int32Array || Int32Array;
    global.Uint32Array = global.Uint32Array || Uint32Array;
    global.Float32Array = global.Float32Array || Float32Array;
    global.Float64Array = global.Float64Array || Float64Array;
  }());

  //
  // 6 The DataView View Type
  //

  (function() {
    function r(array, index) {
      return IsCallable(array.get) ? array.get(index) : array[index];
    }

    var IS_BIG_ENDIAN = (function() {
      var u16array = new Uint16Array([0x1234]),
          u8array = new Uint8Array(u16array.buffer);
      return r(u8array, 0) === 0x12;
    }());

    // DataView(buffer, byteOffset=0, byteLength=undefined)
    // WebIDL: Constructor(ArrayBuffer buffer,
    //                     optional unsigned long byteOffset,
    //                     optional unsigned long byteLength)
    function DataView(buffer, byteOffset, byteLength) {
      if (!(buffer instanceof ArrayBuffer || Class(buffer) === 'ArrayBuffer')) throw TypeError();

      byteOffset = ToUint32(byteOffset);
      if (byteOffset > buffer.byteLength)
        throw RangeError('byteOffset out of range');

      if (byteLength === undefined)
        byteLength = buffer.byteLength - byteOffset;
      else
        byteLength = ToUint32(byteLength);

      if ((byteOffset + byteLength) > buffer.byteLength)
        throw RangeError('byteOffset and length reference an area beyond the end of the buffer');

      Object.defineProperty(this, 'buffer', {value: buffer});
      Object.defineProperty(this, 'byteLength', {value: byteLength});
      Object.defineProperty(this, 'byteOffset', {value: byteOffset});
    };

    // get DataView.prototype.buffer
    // get DataView.prototype.byteLength
    // get DataView.prototype.byteOffset
    // -- applied directly to instances by the constructor

    function makeGetter(arrayType) {
      return function GetViewValue(byteOffset, littleEndian) {
        byteOffset = ToUint32(byteOffset);

        if (byteOffset + arrayType.BYTES_PER_ELEMENT > this.byteLength)
          throw RangeError('Array index out of range');

        byteOffset += this.byteOffset;

        var uint8Array = new Uint8Array(this.buffer, byteOffset, arrayType.BYTES_PER_ELEMENT),
            bytes = [];
        for (var i = 0; i < arrayType.BYTES_PER_ELEMENT; i += 1)
          bytes.push(r(uint8Array, i));

        if (Boolean(littleEndian) === Boolean(IS_BIG_ENDIAN))
          bytes.reverse();

        return r(new arrayType(new Uint8Array(bytes).buffer), 0);
      };
    }

    Object.defineProperty(DataView.prototype, 'getUint8', {value: makeGetter(Uint8Array)});
    Object.defineProperty(DataView.prototype, 'getInt8', {value: makeGetter(Int8Array)});
    Object.defineProperty(DataView.prototype, 'getUint16', {value: makeGetter(Uint16Array)});
    Object.defineProperty(DataView.prototype, 'getInt16', {value: makeGetter(Int16Array)});
    Object.defineProperty(DataView.prototype, 'getUint32', {value: makeGetter(Uint32Array)});
    Object.defineProperty(DataView.prototype, 'getInt32', {value: makeGetter(Int32Array)});
    Object.defineProperty(DataView.prototype, 'getFloat32', {value: makeGetter(Float32Array)});
    Object.defineProperty(DataView.prototype, 'getFloat64', {value: makeGetter(Float64Array)});

    function makeSetter(arrayType) {
      return function SetViewValue(byteOffset, value, littleEndian) {
        byteOffset = ToUint32(byteOffset);
        if (byteOffset + arrayType.BYTES_PER_ELEMENT > this.byteLength)
          throw RangeError('Array index out of range');

        // Include the DataView's base offset, as the matching getter does.
        byteOffset += this.byteOffset;
        // Get bytes
        var typeArray = new arrayType([value]),
            byteArray = new Uint8Array(typeArray.buffer),
            bytes = [], i, byteView;

        for (i = 0; i < arrayType.BYTES_PER_ELEMENT; i += 1)
          bytes.push(r(byteArray, i));

        // Flip if necessary
        if (Boolean(littleEndian) === Boolean(IS_BIG_ENDIAN))
          bytes.reverse();

        // Write them
        byteView = new Uint8Array(this.buffer, byteOffset, arrayType.BYTES_PER_ELEMENT);
        byteView.set(bytes);
      };
    }

    Object.defineProperty(DataView.prototype, 'setUint8', {value: makeSetter(Uint8Array)});
    Object.defineProperty(DataView.prototype, 'setInt8', {value: makeSetter(Int8Array)});
    Object.defineProperty(DataView.prototype, 'setUint16', {value: makeSetter(Uint16Array)});
    Object.defineProperty(DataView.prototype, 'setInt16', {value: makeSetter(Int16Array)});
    Object.defineProperty(DataView.prototype, 'setUint32', {value: makeSetter(Uint32Array)});
    Object.defineProperty(DataView.prototype, 'setInt32', {value: makeSetter(Int32Array)});
    Object.defineProperty(DataView.prototype, 'setFloat32', {value: makeSetter(Float32Array)});
    Object.defineProperty(DataView.prototype, 'setFloat64', {value: makeSetter(Float64Array)});

    global.DataView = global.DataView || DataView;

  }());

}(self));

// Early WebKit typed arrays lack subarray(); the result must share its buffer.
(function (global) {
    function install(Constructor) {
        if (!Constructor || Constructor.prototype.subarray) return;
        Constructor.prototype.subarray = function (start, end) {
            var length = this.length;
            function bound(value) {
                value = Number(value) || 0;
                value = value < 0 ? Math.ceil(value) : Math.floor(value);
                return value < 0 ? Math.max(length + value, 0) : Math.min(value, length);
            }
            start = bound(start);
            end = end === undefined ? length : bound(end);
            return new Constructor(this.buffer, this.byteOffset + start * Constructor.BYTES_PER_ELEMENT, Math.max(end - start, 0));
        };
    }
    var names = ['Int8Array','Uint8Array','Uint8ClampedArray','Int16Array','Uint16Array','Int32Array','Uint32Array','Float32Array','Float64Array'];
    for (var i = 0; i < names.length; i++) install(global[names[i]]);
}(this));
