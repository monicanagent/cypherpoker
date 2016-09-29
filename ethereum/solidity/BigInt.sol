contract BigInt {

   uint[] public number1=[234, 0, 0, 0, 0, 0, 0, 0, 0, 0];
   uint[] public number2=[65, 0, 0, 0, 0, 0, 0, 0, 0, 0];
   uint[] public number3=[18945, 30517, 0, 0, 0, 0, 0, 0, 0, 0];
   bool public zero;
   uint public result;
   
   uint public bpe; //bits stored per array element (15 for standard JavaScript implementation)
   uint public mask;  //AND this with an array element to chop it down to bpe bits
   uint radix;  //equals 2^bpe.  A single 1 bit to the left of the last bit of mask.
   
   uint[] public s0;       //used in multMod_()
   uint[] public s3;       //used in powMod_()
   uint[] public s4;       //used in mod_()
   uint[] public s5;       //used in mod_()
   uint[] public s6;       //used in bigInt2str()
   uint[] public s7;       //used in powMod_()
   uint[] public sa;       //used in mont_()
   byte[] public cArr; //used in uint2String()
   string digitsStr="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_=!@#$%^&*()[]{}|;:,.<>/?`~ \\\'\"+-";
   uint[] one;

    
   function BigInt() public {
        //for (bpe=0; shl(1,(bpe+1)) > shl(1,bpe); bpe++){}  //bpe=number of bits in the mantissa on this platform
	    //shr (bpe,1);                   //bpe=number of bits in one element of the array representing the bigInt
	    bpe=15; //Geth/Browser JS interpreter BPE
        mask=shl(1, bpe)-1;           //AND the mask with an integer to get its bpe least significant bits
        radix=mask+1;              //2^bpe.  a single 1 bit to the left of the first bit of mask
        one=int2bigInt(1,16,1);
        //result=int2bigInt(2232995653,256,10); //[4f45,a31,2] or [20293, 2609, 2]
        //result2=str2bigInt("2232995653",10,5);
        //number1=str2bigInt("234",10,10);
        //number2=str2bigInt("65",10,10);
        //number3=str2bigInt("1000000001",10,10);
       // powMod_(number1,number2,number3);
   }
   
   function bool2uint(bool val) private returns (uint) {
       if (val) {
           return (1);
       } else {
           return (0);
       }
   }
   
   
   //do x=x**y mod n, where x,y,n are bigInts and ** is exponentiation.  0**0=1.
//this is faster when n is odd.  x usually needs to have as many elements as n.
function powMod_(uint[] memory x,uint[] y,uint[] n) private {
  //  var k1,k2,kn,np;
  uint k1;
  uint k2;
  uint kn;
  uint np;
  if(s7.length!=n.length)
    s7=dup(n);

  //for even modulus, use a simple square-and-multiply algorithm,
  //rather than using the more complex Montgomery algorithm.
  if ((n[0]&1)==0) {
    copy_(s7,x);
    copyInt_(x,1);
    while(!equalsInt(y,0)) {
      //if (y[0]&1)
      if ((y[0]&1)!=0)
        multMod_(x,s7,n);
      divInt_(y,2);
      squareMod_(s7,n); 
    }
    return;
  }

  //calculate np from n for the Montgomery multiplications
  copyInt_(s7,0);

 // for (kn=n.length;kn>0 && !n[kn-1];kn--);
  for (kn=n.length;(kn>0) && (n[kn-1]==0);kn--){}

  np=radix-inverseModInt(modInt(n,radix),radix);

  s7[kn]=1;
  multMod_(x ,s7,n);   // x = x * 2**(kn*bp) mod n

  if (s3.length!=x.length) {
    s3=dup(x);
 } else {
    copy_(s3,x);
}

//  for (k1=y.length-1;k1>0 & !y[k1]; k1--);  //k1=first nonzero element of y
  for (k1=y.length-1;(bool2uint(k1>0) & bool2uint(y[k1]==0))!=0; k1--){}
  if (y[k1]==0) { 
    copyInt_(x,1);
    return;
  }
 
 // for (k2=1<<(bpe-1);k2 && !(y[k1] & k2); k2>>=1);  //k2=position of first 1 bit in y[k1]
  for (k2=shl(1,bpe-1);(k2!=0) && ((y[k1] & k2)==0); shr(k2,1)){}  //k2=position of first 1 bit in y[k1]
 k1++; //original implementation uses Number which can be negative so increase here and update "if" below
 for (;;) {
   // if (!(k2>>=1)) {  //look at next bit of y
    k2=shr(k2,1);
    if (k2==0) {
      k1--;
      //if (k1<0) {
      if (k1<1) { //since it's a uint
        mont_(x,one,n,np);
        return;
      }
      //k2=1<<(bpe-1);
      k2=shl(1,bpe-1);
    }    
    mont_(x,x,n,np);
    k1--; //revert back after add above
    //if (k2 & y[k1]) //if next bit is a 1
    if ((k2 & y[k1])!=0) {
      mont_(x,s3,n,np);
    }
  }
  
}
 
//do x=x*y*Ri mod n for bigInts x,y,n, 
//  where Ri = 2**(-kn*bpe) mod n, and kn is the 
//  number of elements in the n array, not 
//  counting leading zeros.  
//x array must have at least as many elemnts as the n array
//It's OK if x and y are the same variable.
//must have:
//  x,y < n
//  n is odd
//  np = -(n^(-1)) mod radix
function mont_(uint[] memory x,uint[] memory y,uint[] memory n,uint np) private {
//  var i,j,c,ui,t,ks;
 // var kn=n.length;
  //var ky=y.length;
  uint i;
  uint j;
  uint c;
  uint ui;
  uint t;
  uint ks;
  uint kn=n.length;
  uint ky=y.length;

  if (sa.length!=kn) 
   // sa=new Array(kn);
   sa=new uint[](kn);
  copyInt_(sa,0);

  //for (;kn>0 && n[kn-1]==0;kn--); //ignore leading zeros of n
  for (;kn>0 && n[kn-1]==0;kn--){}
  //for (;ky>0 && y[ky-1]==0;ky--); //ignore leading zeros of y
  for (;ky>0 && y[ky-1]==0;ky--){}
  ks=sa.length-1; //sa will never have more than this many nonzero elements.  

  //the following loop consumes 95% of the runtime for randTruePrime_() and powMod_() for large numbers
  for (i=0; i<kn; i++) {
    t=sa[0]+x[i]*y[0];
    ui=((t & mask) * np) & mask;  //the inner "& mask" was needed on Safari (but not MSIE) at one time
    //c=(t+ui*n[0]) >> bpe;
    c=shr((t+ui*n[0]), bpe);
    t=x[i];
    
    //do sa=(sa+x[i]*y+ui*n)/b   where b=2**bpe.  Loop is unrolled 5-fold for speed
    j=1;
    /*
    for (;j<ky-4;) { c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++; }    
    for (;j<ky;)   { c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c>>=bpe;   j++; }
    for (;j<kn-4;) { c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++; }  
    for (;j<kn;)   { c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c>>=bpe;   j++; }   
    for (;j<ks;)   { c+=sa[j];                  sa[j-1]=c & mask;   c>>=bpe;   j++; }  
    */
    for (;j<ky-4;) { c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++; }    
    for (;j<ky;)   { c+=sa[j]+ui*n[j]+t*y[j];   sa[j-1]=c & mask;   c=shr(c,bpe);   j++; }
    for (;j<kn-4;) { c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++;
                     c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++; }  
    for (;j<kn;)   { c+=sa[j]+ui*n[j];          sa[j-1]=c & mask;   c=shr(c,bpe);   j++; }   
    for (;j<ks;)   { c+=sa[j];                  sa[j-1]=c & mask;   c=shr(c,bpe);   j++; }
    sa[j-1]=c & mask;
  }

  if (!greater(n,sa))
    sub_(sa,n);
  copy_(x,sa);
}

//is x > y? (x and y both nonnegative)
function greater(uint[] memory x,uint[] memory y) private returns (bool) {
  //var i;
  uint i;
  uint k=(x.length<y.length) ? x.length : y.length;

  for (i=x.length;i<y.length;i++)
    //if (y[i])
    if (y[i]!=0)
      return false;  //y has more digits

  for (i=y.length;i<x.length;i++)
    //if (x[i])
    if (x[i]!=0)
      return true;  //x has more digits

  for (i=k-1;i>=0;i--)
    if (x[i]>y[i])
      return true;
    else if (x[i]<y[i])
      return false;
  return false;
}

//do x=x-y for bigInts x and y.
//x must be large enough to hold the answer.
//negative answers will be 2s complement
function sub_(uint[] memory x,uint[] memory y) {
  //var i,c,k,kk;
  uint i=0;
  uint c=0;
  uint k;
  uint kk;
  k=x.length<y.length ? x.length : y.length;
  for (;i<k;i++) {
    c+=x[i]-y[i];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
  //for (i=k;c && i<x.length;i++) {
  for (i=k;(c!=0) && (i<x.length);i++) {
    c+=x[i];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
}

//is (x << (shift*bpe)) > y?
//x and y are nonnegative bigInts
//shift is a nonnegative integer
function greaterShift(uint[] memory x,uint[] memory y,uint shift) private returns (bool) {
  //var i, kx=x.length, ky=y.length;
  uint i;
  uint kx=x.length;
  uint ky=y.length;
  uint k=((kx+shift)<ky) ? (kx+shift) : ky;
  for (i=ky-1-shift; i<kx && i>=0; i++) 
    if (x[i]>0)
      return true; //if there are nonzeros in x to the left of the first column of y, then x is bigger
  for (i=kx-1+shift; i<ky; i++)
    if (y[i]>0)
      return false; //if there are nonzeros in y to the left of the first column of x, then x is not bigger
  for (i=k-1; i>=shift; i--)
    if      (x[i-shift]>y[i]) return true;
    else if (x[i-shift]<y[i]) return false;
  return false;
}

//do x=x-(y<<(ys*bpe)) for bigInts x and y, and integers a,b and ys.
//x must be large enough to hold the answer.
function subShift_(uint[] memory x,uint[] memory y,uint ys) {
  //var i,c,k,kk;
  uint i=ys;
  uint c=0;
  uint k=x.length<ys+y.length ? x.length : ys+y.length;
  uint kk=x.length;
  //for (c=0,i=ys;i<k;i++) {
  for (;i<k;i++) {
    c+=x[i]-y[i-ys];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
  //for (i=k;c && i<kk;i++) {
  for (i=k;(c!=0) && (i<kk);i++) {
    c+=x[i];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
}

//do x=x*x mod n for bigInts x,n.
function squareMod_(uint[] memory x,uint[] n) private {
 // var i,j,d,c,kx,kn,k;
 uint i;
 uint j;
 uint d;
 uint c;
 uint kx;
 uint kn;
 uint k;
 // for (kx=x.length; kx>0 && !x[kx-1]; kx--);  //ignore leading zeros in x
  for (kx=x.length; kx>0 && (x[kx-1]==0); kx--){}
  k=kx>n.length ? 2*kx : 2*n.length; //k=# elements in the product, which is twice the elements in the larger of x and n
  if (s0.length!=k) 
   // s0=new Array(k);
   s0=new uint[](k);
  copyInt_(s0,0);
  for (i=0;i<kx;i++) {
    c=s0[2*i]+x[i]*x[i];
    s0[2*i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
    for (j=i+1;j<kx;j++) {
      c=s0[i+j]+2*x[i]*x[j]+c;
      s0[i+j]=(c & mask);
      //c>>=bpe;
      c=shr(c,bpe);
    }
    s0[i+kx]=c;
  }
  mod_(s0,n);
  copy_(x,s0);
}

//return x**(-1) mod n, for integers x and n.  Return 0 if there is no inverse
function inverseModInt(uint x,uint n) returns (uint) {
  //var a=1,b=0,t;
  uint a=1;
  uint b=0;
  uint t;
  for (;;) {
    if (x==1) return a;
    if (x==0) return 0;
    //b-=a*Math.floor(n/x);
   // b-=a*(n/x);
    b+=a*(n/x);
    n%=x;

    //if (n==1) return b; //to avoid negatives, change this b to n-b, and each -= to +=
    if (n==1) return (n-b);
    if (n==0) return 0;
    //a-=b*Math.floor(x/n);
    //a-=b*(x/n);
    a+=b*(x/n);
    x%=n;
  }
}

//return x mod n for bigInt x and integer n.
function modInt(uint[] memory x,uint n) private returns (uint) {
  //var i,c=0;
  uint i=x.length;
  uint c=0;
  //for (i=x.length-1; i>=0; i--)
  for (i=x.length-1; i!=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; i--)
    c=(c*radix+x[i])%n;
  return c;
}

//is bigint x equal to integer y?
//y must have less than bpe bits
function equalsInt(uint[] x,uint y) returns (bool) {
  uint i;
  if (x[0]!=y)
    return false;
  for (i=1;i<x.length;i++) {
    if (x[i]==1)
      return false;
  }
  return true;
}

//do x=x*y mod n for bigInts x,y,n.
//for greater speed, let y<x.
function multMod_(uint[] memory x,uint[] y,uint[] n) private {
  uint i;
  if (s0.length!=2*x.length)
   // s0=new Array(2*x.length);
   s0=new uint[](2*x.length);
  copyInt_(s0,0);
  for (i=0;i<y.length;i++)
   // if (y[i])
    if (y[i]!=0)
      //linCombShift_(s0,x,y[i],i);   //s0=1*s0+y[i]*(x<<(i*bpe))
       linCombShift_(s0,x,y[i],i,0);   //s0=1*s0+y[i]*(x<<(i*bpe))
  mod_(s0,n);
  copy_(x,s0);
}

//do x=x mod n for bigInts x and n.
function mod_(uint[] memory x,uint[] n) private {
  if (s4.length!=x.length)
    s4=dup(x);
  else
    copy_(s4,x);
  if (s5.length!=x.length)
    s5=dup(x);  
  divide_(s4,n,s5,x);  //x = remainder of s4 / n
}

//divide x by y giving quotient q and remainder r.  (q=floor(x/y),  r=x mod y).  All 4 are bigints.
//x must have at least one leading zero element.
//y must be nonzero.
//q and r must be arrays that are exactly the same length as x. (Or q can have more).
//Must have x.length >= y.length >= 2.
function divide_(uint[] memory x,uint[] memory y,uint[] memory q,uint[] memory r) private {
 //var kx, ky;
  //var i,j,y1,y2,c,a,b;
  uint kx;
  uint ky;
  uint i;
  uint j;
  uint y1;
  uint y2;
  uint c;
  uint a;
  uint b;
  copy_(r,x);
 // for (ky=y.length;y[ky-1]==0;ky--); //ky is number of elements in y, not including leading zeros
  for (ky=y.length;y[ky-1]==0;ky--){} //ky is number of elements in y, not including leading zeros}}

  //normalize: ensure the most significant element of y has its highest bit set  
  b=y[ky-1];
  //for (a=0; b; a++)
//    b>>=1;
  for (a=0; (b!=0); a++)
      b=shr(b,1);
  a=bpe-a;  //a is how many bits to shift so that the high order bit of y is leftmost in its array element
  leftShift_(y,a);  //multiply both by 1<<a now, then divide both by that at the end
  leftShift_(r,a);

  //Rob Visser discovered a bug: the following line was originally just before the normalization.
 // for (kx=r.length;r[kx-1]==0 && kx>ky;kx--); //kx is number of elements in normalized x, not including leading zeros
  for (kx=r.length;r[kx-1]==0 && kx>ky;kx--){}

  copyInt_(q,0);                      // q=0
  while (!greaterShift(y,r,kx-ky)) {  // while (leftShift_(y,kx-ky) <= r) {
    subShift_(r,y,kx-ky);             //   r=r-leftShift_(y,kx-ky)
    q[kx-ky]++;                       //   q[kx-ky]++;
  }                                   // }

  for (i=kx-1; i>=ky; i--) {
    if (r[i]==y[ky-1])
      q[i-ky]=mask;
    else
     // q[i-ky]=Math.floor((r[i]*radix+r[i-1])/y[ky-1]);
      q[i-ky]=(r[i]*radix+r[i-1])/y[ky-1];

    //The following for(;;) loop is equivalent to the commented while loop, 
    //except that the uncommented version avoids overflow.
    //The commented loop comes from HAC, which assumes r[-1]==y[-1]==0
    //  while (q[i-ky]*(y[ky-1]*radix+y[ky-2]) > r[i]*radix*radix+r[i-1]*radix+r[i-2])
    //    q[i-ky]--;    
    for (;;) {
      y2=(ky>1 ? y[ky-2] : 0)*q[i-ky];
      //c=y2>>bpe;
      c=shr(y2,bpe);
      y2=y2 & mask;
      y1=c+q[i-ky]*y[ky-1];
      //c=y1>>bpe;
      c=shr(y1,bpe);
      y1=y1 & mask;

      if (c==r[i] ? y1==r[i-1] ? y2>(i>1 ? r[i-2] : 0) : y1>r[i-1] : c>r[i]) 
        q[i-ky]--;
      else
        break;
    }

    //linCombShift_(r,y,-q[i-ky],i-ky);    //r=r-q[i-ky]*leftShift_(y,i-ky)
    linCombShift_(r,y,-q[i-ky],i-ky,0);    //r=r-q[i-ky]*leftShift_(y,i-ky)
    if (negative(r)) {
      addShift_(r,y,i-ky);         //r=r+leftShift_(y,i-ky)
      q[i-ky]--;
    }
  }

  rightShift_(y,a);  //undo the normalization step
  rightShift_(r,a);  //undo the normalization step
}

//do x=x+(y<<(ys*bpe)) for bigInts x and y, and integers a,b and ys.
//x must be large enough to hold the answer.
function addShift_(uint[] memory x,uint[] memory y,uint ys) {
  //var i,c,k,kk;
  //k=x.length<ys+y.length ? x.length : ys+y.length;
  //kk=x.length;
  uint i=ys;
  uint c=0;
  uint k=x.length<ys+y.length ? x.length : ys+y.length;
  uint kk=x.length;
  for (;i<k;i++) {
    c+=x[i]+y[i-ys];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
  for (i=k;(c!=0) && i<kk;i++) {
    c+=x[i];
    x[i]=c & mask;
    //c>>=bpe;
    c=shr(c,bpe);
  }
}

//is bigInt x negative?
function negative(uint[] memory x) private returns (bool) {
  //return ((x[x.length-1]>>(bpe-1))&1);
  if (shr(x[x.length-1],(bpe-1)&1)==1) {
      return (true);
  } else {
      return (false);
  }
}

//left shift bigInt x by n bits.
function leftShift_(uint[] memory x,uint n) {
  //var i;
  uint i;
  //var k=Math.floor(n/bpe);
  uint k=n/bpe;
  //if (k) {
  if (k!=0) {
    for (i=x.length; i>=k; i--) //left shift x by k elements
      x[i]=x[i-k];
    for (;i>=0;i--)
      x[i]=0;  
    n%=bpe;
  }
  //if (!n)
  if (n==0)
    return;
  for (i=x.length-1;i>0;i--) {
    //x[i]=mask & ((x[i]<<n) | (x[i-1]>>(bpe-n)));
    x[i]=mask & (shl(x[i],n) | shr(x[i-1],(bpe-n)));
  }
  //x[i]=mask & (x[i]<<n);
  x[i]=mask & shl(x[i],n);
}

//right shift bigInt x by n bits.  0 <= n < bpe.
function rightShift_(uint[] memory x,uint n) private {
 // var i;
 uint i;
  //var k=Math.floor(n/bpe);
  uint k=n/bpe;
  //if (k) {
  if (k!=0) {
    for (i=0;i<x.length-k;i++) //right shift x by k elements
      x[i]=x[i+k];
    for (;i<x.length;i++)
      x[i]=0;
    n%=bpe;
  }
  for (i=0;i<x.length-1;i++) {
    //x[i]=mask & ((x[i+1]<<(bpe-n)) | (x[i]>>n));
    x[i]=mask & (shl(x[i+1],(bpe-n))) | (shr(x[i],n));
  }
  //x[i]>>=n;
  x[i]=shr(x[i],n);
}
   
    //do the linear combination x=a*x+b*(y<<(ys*bpe)) for bigInts x and y, and integers a, b and ys.
    //x must be large enough to hold the answer.
    function linCombShift_(uint[] x, uint[] y, uint a, uint b, uint ys) returns (uint[]){
	  uint i;
	  uint c;
	  uint k;
	  uint kk;
	  k=x.length<ys+y.length ? x.length : ys+y.length;
	  kk=x.length;
	  c=0;
	  for (i=ys;i<k;i++) {
		c+=x[i]+b*y[i-ys];
		x[i]=c & mask;
		shr(c,bpe);
	  }
	  for (i=k;(c==1) && (i < kk);i++) {
		c+=x[i];
		x[i]=c & mask;
		shr(c,bpe);
	  }
	  return (x);
	}
	
	//do x=x*n where x is a bigInt and n is an integer.
	//x must be large enough to hold the result.
	function multInt_(uint[] x,uint n) {
	  uint i;
	  uint k;
	  uint c;
	  uint b;
	  k=x.length;
	  c=0;
	  for (i=0;i<k;i++) {
		c+=x[i]*n;
		b=0;
		/*
		//c can't be < 0!
		if (c<0) {
		  b=-(c>>bpe);
		  c+=b*radix;
		}
		*/
		x[i]=c & mask;
		c=shr(c,bpe)-b;
		//c=(c>>bpe)-b;
	  }
	}
	
	//do x=x+n where x is a bigInt and n is an integer.
    //x must be large enough to hold the result.
    function addInt_(uint[] memory x,uint n) {
      uint i;
	  uint k;
	  uint c;
	  uint b;
      x[0]+=n;
      k=x.length;
      c=0;
      for (i=0;i<k;i++) {
        c+=x[i];
        b=0;
        /*
        if (c<0) {
          b=-(c>>bpe);
          c+=b*radix;
        }
        */
        x[i]=c & mask;
        //c=(c>>bpe)-b;
        c=shr(c,bpe)-b;
        if (c==0) return; //stop carrying as soon as the carry is zero
      }
    }
    

    //return the bigInt given a string representation in a given base.  
    //Pad the array with leading zeros so that it has at least minSize elements.
    //If base=0 (fomerly -1), then it reads in a space-separated list of array elements in decimal.
    //The array will always have at least one leading zero, unless base=-1.
    function str2bigInt(string s,uint base,uint minSize) returns (uint[]) {
    int d;
    uint i;
    uint j;
    uint[] memory x;
    uint[] memory y;
    uint kk;
    var k=bytes(s).length;
    if (base==0) { //comma-separated list of array elements in decimal
        //x=new Array(0);
        x=new uint[](0);
        for (;;) {
            //y=new Array(x.length+1);
            //y.length=0;
            y=new uint[](x.length+1);
            for (i=0;i<x.length;i++)
                y[i+1]=x[i];
            y[0]=parseInt(s);
            x=y;
            //d=s.indexOf(s,',',0);
            d=indexOf(s, ",", 0);
            if (d<1) 
                break;
            //s=s.substring(d+1);
            s=subString(s, uint(d)+1, strLength(s));
            //if (s.length==0)
            if (strLength(s)==0)
                break;
        }
        if (x.length<minSize) {
            //y=new Array(minSize);
            y=new uint[](minSize);
            copy_(y,x);
            return y;
        }
        return x;
    }
    x=int2bigInt(0,base*k,0);
    for (i=0;i<k;i++) {
        //d=digitsStr.indexOf(s.substring(i,i+1),0);
        d=indexOf(digitsStr, subString(s,i,i+1), 0);
        if (base<=36 && d>=36)  //convert lowercase to uppercase if base<=36
            d-=26;
        if (uint(d)>=base || d<0) {   //stop at first illegal character
         break;
        }
        multInt_(x,base);
        addInt_(x,uint(d));
      }
      
   // for (k=x.length;k>0 && !x[k-1];k--); //strip off leading zeros
    for (k=x.length;(k>0) && (x[k-1]==0);k--){} //strip off leading zeros
    k=minSize>k+1 ? minSize : k+1;
    //y=new Array(k);
    y=new uint[](k);
    kk=k<x.length ? k : x.length;
    for (i=0;i<kk;i++)
        y[i]=x[i];
    for (;i<k;i++)
        y[i]=0;

    return y;
}

    //convert a bigInt into a string in a given base, from base 2 up to base 95.
    //Base 0 (formerly -1) prints the contents of the array representing the number.
    function bigInt2str(uint[] x,uint base) returns (string) {
      uint i;
      uint t;
      string memory s;
    
      if (s6.length!=x.length) {
        s6=dup(x);
      } else {
        copy_(s6,x);
      }
    if (base==0) { //note change of base value from original implementation
     // if (base==-1) { //return the list of array contents
        for (i=x.length-1;i>0;i--) {
         //    s+=x[i]+',';
            s=appendString(s,uint2String(x[i]));
            s=appendString(s,",");
        }
        //s+=x[0];
        s=appendString(s,uint2String(x[0]));
      }
      else { //return it in the given base
        while (!isZero(s6)) {
          t=divInt_(s6,base);  //t=s6 % base; s6=floor(s6/base);
       //   s=digitsStr.subString(t,t+1)+s;
          s=appendString(subString(digitsStr, t, t+1), s);
        }
      }
      if (strLength(s)==0) {
        s="0";
      }
      return s;
    }
    
     function indexOf (string inp, string find, uint startPos) returns (int) {
        uint matchCount=0;
        for (uint x=startPos; x<bytes(inp).length; x++) {
            if (bytes(inp)[x]==bytes(find)[matchCount]) {
                matchCount++;
            } else {
                matchCount=0;
            }
            if (matchCount==uint(bytes(find).length)) {
                return (int(x-matchCount+1));
            }
        }
        return (-1);
    }
    
    /**
     * Converts a numeric base 10 string to a native unsigned integer (similar to JavaScript parseInt).
     */
    function parseInt (string inp) returns (uint) {
        uint multiplier=1;
        uint ret=0;
        for (uint x=bytes(inp).length; x>0; x--) {
            ret+=(uint(bytes(inp)[x-1])-48)*multiplier;
            multiplier*=10;
        }
        return (ret);
    }
    
    function uint2String(uint val) returns (string) {
        uint isol;
        
        if (val == 0) {
            return ("0");
        } else {
            while (val > 0) {
                isol=val-((val/10)*10);
                cArr.push (byte(isol+48));
                val /= 10;
            }
        }
        bytes memory str=new bytes(cArr.length);
        uint count;
        for (count=0; count<cArr.length; count++) {
            str[cArr.length-1-count]=byte(cArr[count]);
        }
        return (string(str));
    }
    
    function strLength(string inp) private returns (uint) {
        return (bytes(inp).length);
    }
    
    //do x=floor(x/n) for bigInt x and integer n, and return the remainder
    function divInt_(uint[] memory x,uint n) private returns (uint) {
      uint i;
      uint r=0;
      uint s;
      for (i=x.length;i>0;i--) {
        s=r*radix+x[i-1];
        x[i-1]=s/n;
        r=s%n;
      }
      return r;
    }
    
    function subString (string source, uint startIndex, uint endIndex) returns (string) {
        if (endIndex<=startIndex) {
            return "";
        }
        bytes memory _source=bytes(source);
        if (endIndex > _source.length) {
            endIndex=_source.length;
        }
        string memory _subString=new string(endIndex-startIndex);
        bytes memory returnStr=bytes(_subString);
        uint count;
        uint appendIndex=0;
        for (count=startIndex; count<endIndex; count++) {
            returnStr[appendIndex++]=_source[count];
        }
        return string(returnStr);
    }
    
    function appendString(string appendTo, string appendFrom) returns (string) {
        bytes memory _appendTo = bytes(appendTo);
        bytes memory _appendFrom = bytes(appendFrom);
        string memory _concatString = new string(_appendTo.length+_appendFrom.length);
        bytes memory returnStr=bytes(_concatString);
        uint count;
        uint appendIndex=0;
        for (count=0; count<_appendTo.length; count++) {
            returnStr[appendIndex++]=_appendTo[count];
        }
         for (count=0; count<_appendFrom.length; count++) {
            returnStr[appendIndex++]=_appendFrom[count];
        }
        return string(returnStr);
    }
    
    //returns a duplicate of bigInt x
    function dup(uint[] x) public returns (uint[]) {
      uint[] memory buff=new uint[](x.length);
      copy_(buff,x);
      return buff;
    }
    
    //do x=y on bigInts x and y.  x must be an array at least as big as y (not counting the leading zeros in y).
    function copy_(uint[] memory x,uint[] y) private {
      uint i;
      uint  k=x.length<y.length ? x.length : y.length;
      for (i=0;i<k;i++)
        x[i]=y[i];
      for (i=k;i<x.length;i++)
        x[i]=0;
    }
    
    //is the bigInt x equal to zero?
    function isZero(uint[] x) private returns (bool) {
      uint i;
      for (i=0;i<x.length;i++) {
        if (x[i]!=0)
          return false;
      }
      return true;
    }
   
    //do x=y on bigInt x and integer y.  
    function copyInt_(uint[] x,uint n) private {
      uint i;
      uint c;
      c=n;
      for (i=0;i<x.length;i++) {
        x[i]=c & mask;
        c=shr(c,bpe);
      }
    }
   
   //convert the integer t into a bigInt with at least the given number of bits.
    //the returned array stores the bigInt in bpe-bit chunks, little endian (buff[0] is least significant word)
    //Pad the array with leading zeros so that it has at least minSize elements.
    //There will always be at least one leading 0 element.
    function int2bigInt(uint t,uint bits,uint minSize) returns (uint[]){   
      uint i;
      uint k;
     // k=Math.ceil(bits/bpe)+1;
     k=(bits/bpe);
     
      if ((bits % bpe) != 0) {
          k+=2;
      } else {
          k+=1;
      }
     
      k=minSize>k ? minSize : k;
      uint[] memory buff=new uint[](k);
      copyInt_(buff,t);
      return buff;
    }
   
     /**
     * Shift "x" right by "y" bits and return the result
     */
    function shr(uint x, uint y) public returns (uint) {
        if (y==0) {return x;}
    	return (x / (2**y));
    }
    
    /**
     * Shift "x" left by "y" bits, filling right-most bits with 0s, and return the result.
     */
    function shl(uint x, uint y) public returns (uint) {
        if (y==0) {return x;}
    	return (x * (2**y));
    }
}
