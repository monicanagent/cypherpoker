contract BigInt {

    uint256 public result=0;
    uint256 public loops=0;
    bool public done=false;

    function BigInt() {
    }

    function powMod256(uint256 base, uint256 exponent, uint256 modulus) {
        if (modulus==1) {
            result=0;
            done=true;
            return;
        }
        done=false;
        result=1;
        base = base % modulus;
        while (exponent > 0) {
            if ((exponent % 2) == 1) {
                result = mulmod(result, base, modulus);
                done=true;
            }
            exponent = exponent / 2; //shift right by 1 bit
            base = mulmod(base, base, modulus);
        }
    }
    
    
}