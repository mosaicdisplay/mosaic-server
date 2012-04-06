//This JavaScript library is copyright 2002 by Gavin Kistner
//Reuse or modification permitted provided the previous line is included. 
//mailto:!@phrogz.net 

/***************************************************************************************************
* JavaScript Array Set Mathematics Library
* version 1.5 Jan 27th, 2011  Slim down; Fix FF; Define using non-enumerable methods if avaialble
*
* Methods: array1.union( array2 [,compareFunction] ) 
*          array1.subtract( array2 [,compareFunction] ) 
*          array1.intersect( array2 [,compareFunction] ) 
*          array1.exclusion( array2 [,compareFunction] ) 
*          array1.removeDuplicates( [compareFunction] ) 
*
*          array1.unsortedUnion( array2 [,compareFunction] ) 
*          array1.unsortedSubtract( array2 [,compareFunction] ) 
*          array1.unsortedIntersect( array2 [,compareFunction] ) 
*          array1.unsortedExclusion( array2 [,compareFunction] ) 
*          array1.unsortedRemoveDuplicates( [compareFunction] ) 
*
* Notes:   All methods return a 'set' Array where duplicates have been removed.
*
*          The union(), subtract(), intersect(), and removeDuplicates() methods
*          are faster than their 'unsorted' counterparts, but return a sorted set:
*          var a = ['a','e','c'];
*          var b = ['b','c','d'];
*          a.unsortedUnion(b)  -->  'a','e','c','b','d' 
*          a.union(b)          -->  'a','b','c','d','e' 
*
*          Calling any of the methods on an array whose element pairs cannot all be
*          reliably ordered (objects for which a < b, a > b, and a==b ALL return false) 
*          will produce inaccurate results UNLESS the (usually) optional
*          'compareFunction' parameter is passed. This should specify a custom
*          comparison function, as required by the standard Array.sort(myFunc) method
*          For example:
*          var siblings = [ {name:'Dain'} , {name:'Chandra'} , {name:'Baird'} , {name:'Linden'} ];
*          var brothers = [ {name:'Dain'} , {name:'Baird'} ];
*          function compareNames(a,b){ return (a.name < b.name)?-1:(a.name > b.name)?1:0 } 
*          var sisters=siblings.unsortedSubtract(brothers, compareNames);
*
***************************************************************************************************/ 

(function(){
	var methods = {
		//*** SORTED IMPLEMENTATIONS *************************************************** 
		union : function ArraySetMathUnion(a2,compareFunction){ 
			return this.concat(a2?a2:null).removeDuplicates(compareFunction);
		},
		subtract : function ArraySetMathSubtract(a2,compareFunction){ 
			var a1=this.removeDuplicates(compareFunction);
			if (!a2) return a1;
			var a2=a2.removeDuplicates(compareFunction);
			var len2=a2.length;
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i],found=false,src;
					for (var j=0;j<len2&&compareFunction(src2=a2[j],src)!=1;j++) if (compareFunction(src,src2)==0) { found=true; break; } 
					if (found) a1.splice(i--,1);
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i],found=false,src;
					for (var j=0;(j<len2)&&(src>=(src2=a2[j]));j++) if (src2==src) { found=true; break; } 
					if (found) a1.splice(i--,1);
				} 
			} 
			return a1;
		},
		intersect : function ArraySetMathIntersect(a2,compareFunction){ 
			var a1=this.removeDuplicates(compareFunction);
			if (!a2) return a1;
			var a2=a2.removeDuplicates(compareFunction);
			var len2=a2.length;
			if (len2<a1.length){ 
				var c=a2; a2=a1; a1=c; c=null;
				len2=a2.length;
			} 
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i],found=false,src;
					for (var j=0;j<len2&&compareFunction(src2=a2[j],src)!=1;j++) if (compareFunction(src,src2)==0) { found=true; break; } 
					if (!found) a1.splice(i--,1);
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i],found=false,src;
					for (var j=0;(j<len2)&&(src>=(src2=a2[j]));j++) if (src2==src) { found=true; break; } 
					if (!found) a1.splice(i--,1);
				} 
			} 
			return a1;
		},
		removeDuplicates : function ArraySetMathRemoveDuplicates(compareFunction){ 
			var a1=this.concat(); compareFunction ? a1.sort(compareFunction) : a1.sort();
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=i+1;j<a1.length&&compareFunction(a1[j],src)==0;j++){} 
					if (j-1>i) a1.splice(i+1,j-i-1);
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=i+1;j<a1.length&&a1[j]==src;j++){} 
					if (j-1>i) a1.splice(i+1,j-i-1);
				} 
			} 
			return a1;
		},
		exclusion : function ArraySetMathExclusion(a2,compareFunction){ 
			var a1=this.removeDuplicates(compareFunction);
			if (!a2) return a1;
			var result = a1.subtract(a2,compareFunction).concat(a2.subtract(a1,compareFunction));
			compareFunction ? result.sort(compareFunction) : result.sort();
			return result;
		},

		//*** UNSORTED IMPLEMENTATIONS ************************************************* 
		unsortedUnion : function ArraySetMathUnsortedUnion(a2,compareFunction){ 
			return this.concat(a2?a2:null).unsortedRemoveDuplicates(compareFunction);
		},
		unsortedSubtract : function ArraySetMathUnsortedSubtract(a2,compareFunction){ 
			var a1=this.unsortedRemoveDuplicates(compareFunction);
			if (!a2) return a1;
			var subtrahend=a2.unsortedRemoveDuplicates(compareFunction);
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=0,len=subtrahend.length;j<len;j++) if (compareFunction(subtrahend[j],src)==0) { a1.splice(i--,1); break; } 
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=0,len=subtrahend.length;j<len;j++) if (subtrahend[j]==src) { a1.splice(i--,1); break; } 
				} 
			} 
			return a1;
		},
		unsortedIntersect : function ArraySetMathUnsortedIntersect(a2,compareFunction){ 
			if (!a2) return this.unsortedRemoveDuplicates(compareFunction);
			var a1=this;
			var len2=a2.length;
			a1=a1.unsortedRemoveDuplicates(compareFunction);
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=0;j<len2;j++) if (compareFunction(a2[j],src)==0) break;
					if (j==len2) a1.splice(i--,1);
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=0;j<len2;j++) if (a2[j]==src) break;
					if (j==len2) a1.splice(i--,1);
				} 
			} 
			return a1;
		},
		unsortedRemoveDuplicates : function ArraySetMathUnsortedRemoveDuplicates(compareFunction){ 
			var a1=this.concat();
			if (compareFunction){ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=i+1;j<a1.length;j++) if (compareFunction(a1[j],src)==0) a1.splice(j,1);
				} 
			}else{ 
				for (var i=0;i<a1.length;i++){ 
					var src=a1[i];
					for (var j=i+1;j<a1.length;j++) if (a1[j]==src) a1.splice(j--,1);
				} 
			} 
			return a1;
		},
		unsortedExclusion : function ArraySetMathUnsortedExclusion(a2,compareFunction){ 
			var a1=this.unsortedRemoveDuplicates(compareFunction);
			if (!a2) return a1;
			var result = a1.unsortedSubtract(a2,compareFunction).concat(a2.unsortedSubtract(a1,compareFunction));
			compareFunction ? result.sort(compareFunction) : result.sort();
			return result;
		}
	};
	var useDefineProperty = (typeof Object.defineProperty == 'function');
	for (var methodName in methods){
		if (!methods.hasOwnProperty(methodName)) continue;
		if (useDefineProperty){
			try{
				Object.defineProperty( Array.prototype, methodName, {value:methods[methodName]} );
			}catch(e){}
		}
		if (!Array.prototype[methodName]) Array.prototype[methodName] = methods[methodName];
	}
})();
