#!/bin/sh

cd "$(dirname "$0"/..)"

IMAGE="${IMAGE:-cache-provisioner}"

VOLDIR=pv-xyz1_test-namespace_pvc-xyz
EXPECTED_CONTENT="testcontent $(date)"

# ARGS: SCRIPT
runScript() {
	mkdir -p testmount
	docker run --rm --privileged \
		-e VOL_DIR=/data/$VOLDIR \
		-e VOL_NAME=pv-xyz \
		-e VOL_SIZE_BYTES=12345678 \
		-e PVC_NAME=pvc-xyz \
		-e PVC_NAMESPACE=test-namespace \
		-e PVC_ANNOTATION_CACHE_NAME=test-cache \
		--mount "type=bind,source=`pwd`/e2e/script,target=/script" \
		--mount "type=bind,source=`pwd`/testmount,target=/data,bind-propagation=rshared" \
		--entrypoint=/bin/sh \
		"$IMAGE" \
		"$@"
}

set -e

mkdir -p testmount
rm -rf testmount/$VOLDIR

echo
echo TEST setup
echo
(
	set -ex
	runScript /script/setup
	echo "$EXPECTED_CONTENT" > testmount/$VOLDIR/testfile
	ls -la testmount/$VOLDIR
)

echo
echo TEST teardown
echo
(
	set -ex
	runScript /script/teardown

	[ ! -d testmount/$VOLDIR ] || (echo fail: volume should be removed >&2; false)
)

echo
echo TEST restore
echo
(
	set -ex
	VOLDIR=pv-xyz2_test-namespace_pvc-xyz

	runScript /script/setup

	CONTENT="$(cat testmount/$VOLDIR/testfile)"
	[ "$CONTENT" = "$EXPECTED_CONTENT" ] || (echo fail: volume should return what was last written into that cache key >&2; false)

	runScript /script/teardown
)

echo
echo TEST prune
echo
(
	set -ex
	runScript -c 'buildah() { /usr/bin/buildah --root=/data/.cache/containers/storage "$@"; }; set -ex; buildah from --name c1 scratch; buildah commit c1; buildah rm c1'
	runScript /usr/bin/cache-provisioner prune
)