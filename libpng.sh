#rm -rf libming-CVE-2016-9827
#git clone https://github.com/libming/libming.git libming-CVE-2016-9827
#cd libming-CVE-2016-9827/; 
#git checkout e397b5e
set -e

if [ -z "$AFLGO" ]; then
    echo "AFLGO environment variable is not set. Please set it to the AFLGo path."
    exit 1
fi

export SCRIPTDIR=$PWD

rm -rf libpng
git clone --no-checkout https://githubfast.com/glennrp/libpng.git
git -C libpng checkout dbe3e0c43e549a1602286144d94b0666549b18e6
patch -p1 -d libpng < aah008_abort.patch
cp libpng_read_fuzzer.cc libpng/contrib/oss-fuzz/libpng_read_fuzzer.cc

cp afl_driver.cpp $AFLGO/

cd libpng
rm -rf obj-aflgo
mkdir obj-aflgo; mkdir obj-aflgo/temp
mkdir obj-aflgo/out

export OUT=$PWD/obj-aflgo/out
export SUBJECT=$PWD; export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS=-lpthread
export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps -rdynamic"
export LIBS="-lrt -lstdc++"

# === get BBtargets ===
#echo 'outputtxt.c:143' > $TMP_DIR/BBtargets.txt
#  $AFLGO/scripts/Stackparser.py $AFLGO/scripts/fuzz/libpng_aah001.crash $TMP_DIR/BBtargets.txt
cp ../aah008_BBtargets.txt $TMP_DIR/BBtargets.txt
cp ../aah008_BBtargets.txt $TMP_DIR/BBtargets_final.txt

# === build target program ===
#./autogen.sh;
#cd obj-aflgo; 
#CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
#make clean; 
#make
autoreconf -f -i
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ./configure  --disable-shared
make -j$(nproc) clean
make -j$(nproc) libpng16.la
cp .libs/libpng16.a "$OUT/"
# build libpng_read_fuzzer

export CXXFLAGS="$ADDITIONAL"
$CXX $CXXFLAGS -std=c++11 -c $AFLGO/afl_driver.cpp -fPIC -o "$OUT/afl_driver.o"
$CXX $CXXFLAGS -std=c++11 -I. \
     contrib/oss-fuzz/libpng_read_fuzzer.cc "$OUT/afl_driver.o"\
     -o libpng_read_fuzzer \
     $LDFLAGS .libs/libpng16.a $LIBS -lz
cp libpng_read_fuzzer "$OUT/"
unset CXXFLAGS

# === calculate distance ===
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/BBmapping.py $TMP_DIR/BBtargets.txt $TMP_DIR/BBnames.txt $TMP_DIR/real.txt
$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR libpng_read_fuzzer

# === instrument ===
#cd -; CFLAGS="-distance=$TMP_DIR/distance.cfg.txt -targets=$TMP_DIR/BBtargets_final.txt" CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -targets=$TMP_DIR/BBtargets_final.txt" ../configure --disable-shared --prefix=`pwd`
#make clean; make
CFLAGS="-distance=$TMP_DIR/distance.cfg.txt -targets=$TMP_DIR/BBtargets_final.txt" CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -targets=$TMP_DIR/BBtargets_final.txt" ./configure --disable-shared
make -j$(nproc) clean
make -j$(nproc) libpng16.la
cp .libs/libpng16.a "$OUT/"
export CXXFLAGS="-distance=$TMP_DIR/distance.cfg.txt -targets=$TMP_DIR/BBtargets_final.txt"
$CXX $CXXFLAGS -std=c++11 -c $AFLGO/afl_driver.cpp -fPIC -o "$OUT/afl_driver.o"
$CXX $CXXFLAGS -std=c++11 -I. \
     contrib/oss-fuzz/libpng_read_fuzzer.cc "$OUT/afl_driver.o"\
     -o libpng_read_fuzzer \
     $LDFLAGS .libs/libpng16.a $LIBS -lz
cp libpng_read_fuzzer "$OUT/"
unset CXXFLAGS

# == preparation for fuzz ===
#rm -rf in out
#mkdir in; 
#wget -P in --no-check-certificate http://condor.depaul.edu/sjost/hci430/flash-examples/swf/bumble-bee1.swf
#echo ' ' >in/tmp.swf

# === start fuzz ===
# == example: listswf ==
#$AFLGO/afl-fuzz -m none -z exp -c 45m -i in -o out -d -- @@
#$AFLGO/afl-fuzz -i in -o out -m none -t 9999 -d -- ./util/listswf @@
# ==end example ==

# cd $SCRIPTDIR/libpng_fuzz
# $AFLGO/afl-fuzz -i in -o out -m none -d -- $SCRIPTDIR/libpng/obj-aflgo/out/libpng_read_fuzzer @@

# reproduce
#  $SCRIPTDIR/libpng/obj-aflgo/out/libpng_read_fuzzer  $SCRIPTDIR/aah008_crash_inptut
