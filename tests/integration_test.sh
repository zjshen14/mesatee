#!/bin/bash

trap "pkill -2 -P $$; wait" SIGINT SIGTERM EXIT

cd ../bin

# prepare test data
cp -r ../tests/integration_test/test_data .

# check ports
for port in 5554 5555 3444 6016 5065 5066; do
    if lsof -i :$port; then
        echo "[-] port $port is in use"
        exit 1
    fi
done

# run enclave modules in the background
echo "[+] launching task management service..."
./tms 2>&1 | tee tms.log &

echo "[+] launching function node service..."
./fns 2>&1 | tee fns.log &

echo "[+] launching kms..."
./kms 2>&1 | tee kms.log &

echo "[+] launching trusted_dfs..."
./tdfs 2>&1 | tee tdfs.log &

wait_service() {
    name=$1
    port=$2
    timeout=$3

    echo "[+] waiting $name to launch on port $port... "
    timeout $timeout sh -c 'until lsof -i :$0 >> /dev/null; do sleep 0.5; done' $port || {
        echo "[-] timeout, waiting $name on $port"
        exit 1
    }
    echo "[+] $name launched"
}

wait_service "kms" 6016 30
wait_service "tdfs" 5065 30
wait_service "tdfs" 5066 30
wait_service "tms" 5554 30
wait_service "tms" 5555 30
wait_service "fns" 3444 30

echo "[+] run integration_test"
./integration_test 2>&1 | tee integration_test.log
[ ${PIPESTATUS[0]} -eq 0 ] || exit ${PIPESTATUS[0]}

echo "[+] run three_party_demo"
../examples/private_join_and_compute/three_party_demo.sh > /dev/null
[ $? -eq 0 ] || exit $?
echo "[+] run four_party_demo"
../examples/private_join_and_compute/four_party_demo.sh > /dev/null
[ $? -eq 0 ] || exit $?
echo "[+] run ml_predict_demo"
../examples/ml_predict/ml_predict_demo.sh > /dev/null
[ $? -eq 0 ] || exit $?
echo "[+] run image_resize_demo"
../examples/image_resizing/image_resize_demo.sh 2>&1 | tee image_resize.log
[ ${PIPESTATUS[0]} -eq 0 ] || exit ${PIPESTATUS[0]}
echo "[+] run online_decrypt_demo"
../examples/online_decrypt/online_decrypt_demo.sh 2>&1 | tee decrypt.log
[ ${PIPESTATUS[0]} -eq 0 ] || exit ${PIPESTATUS[0]}
echo "[+] run rsa_sign"
../examples/rsa_sign/rsa_sign.sh 2>&1 | tee rsa_sign.log
[ ${PIPESTATUS[0]} -eq 0 ] || exit ${PIPESTATUS[0]}
echo "[+] run py_matrix_multiply"
../examples/py_matrix_multiply/py_matrix_multiply.sh 2>&1 | tee py_matrix_multiply.log
[ ${PIPESTATUS[0]} -eq 0 ] || exit ${PIPESTATUS[0]}