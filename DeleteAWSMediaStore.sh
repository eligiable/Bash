#apt install jq
#confgiure aws cli

endpoint=https://1q2w3e4r5t.data.mediastore.eu-west-1.amazonaws.com
mspath=stream

aws mediastore-data list-items --endpoint=$endpoint --path=$mspath > output.json
for OUTPUT in $(cat output.json | jq -r '.Items[].Name')
do
        echo ${OUTPUT}
        aws mediastore-data delete-object --endpoint=$endpoint --path=$mspath/${OUTPUT}
done
