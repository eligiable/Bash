#!/bin/bash

#Check if JSON Generation is already Running or Not
ps -aux | grep "[c]tv:json:generate" > /tmp/check-json-script.log
if [[ "$?" == "0" ]]; then
        echo "JSON Generation is already Running."
else
        Checklist=0
        {
        #Check Main JASON Dirs.
        echo "-- Directories under Cache --"
        CachePath="/var/www/magento2/pub/media/cache"
        JSON="$CachePath/categories $CachePath/products"
        set -- $JSON
        JsonDirs=$@
        for i in "$@"
        do
                if [ -d $i ]; then
                        echo "Directory $i Exist."
                else echo "Directory $i DO NOT Exist" && Checklist=1
                fi
        done
        echo $Checklist
        echo \

        #Check Sub-Dirs. under Categories
        echo "-- Directories under Categories --"
        CategoriesPath="/var/www/magento2/pub/media/cache/categories"
        Categories="$CategoriesPath/2 $CategoriesPath/4 $CategoriesPath/5 $CategoriesPath/6 $CategoriesPath/7 $CategoriesPath/8 $CategoriesPath/9 $CategoriesPath/10 $CategoriesPath/11 $CategoriesPath/12 $CategoriesPath/13 $CategoriesPath/14"
        set -- $Categories
        CategoriesDirs=$@
        for i in "$@"
        do
                if [ -d $i ]; then
                        echo "Directory $i Exist."
                else echo "Directory $i DO NOT Exist" && Checklist=1
                fi
        done
        echo $Checklist
        echo \

        #Check JSON under Categories
        echo "-- JSON Found under Categories --"
        FILE=$CategoriesPath/2/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/4/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/5/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/6/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/7/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/8/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/9/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/10/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/11/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/12/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/13/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$CategoriesPath/14/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        echo \

        #Total JSON Files Found under Categories Dir
        echo "-- Total JSON Files Found under Categories --"
        echo -n "StoreID 2 = "; find /var/www/magento2/pub/media/cache/categories/2 -type f -name "*.json" | wc -l
        echo -n "StoreID 4 = "; find /var/www/magento2/pub/media/cache/categories/4 -type f -name "*.json" | wc -l
        echo -n "StoreID 5 = "; find /var/www/magento2/pub/media/cache/categories/5 -type f -name "*.json" | wc -l
        echo -n "StoreID 6 = "; find /var/www/magento2/pub/media/cache/categories/6 -type f -name "*.json" | wc -l
        echo -n "StoreID 7 = "; find /var/www/magento2/pub/media/cache/categories/7 -type f -name "*.json" | wc -l
        echo -n "StoreID 8 = "; find /var/www/magento2/pub/media/cache/categories/8 -type f -name "*.json" | wc -l
        echo -n "StoreID 9 = "; find /var/www/magento2/pub/media/cache/categories/9 -type f -name "*.json" | wc -l
        echo -n "StoreID 10 = "; find /var/www/magento2/pub/media/cache/categories/10 -type f -name "*.json" | wc -l
        echo -n "StoreID 11 = "; find /var/www/magento2/pub/media/cache/categories/11 -type f -name "*.json" | wc -l
        echo -n "StoreID 12 = "; find /var/www/magento2/pub/media/cache/categories/12 -type f -name "*.json" | wc -l
        echo -n "StoreID 13 = "; find /var/www/magento2/pub/media/cache/categories/13 -type f -name "*.json" | wc -l
        echo -n "StoreID 14 = "; find /var/www/magento2/pub/media/cache/categories/14 -type f -name "*.json" | wc -l
        echo \

        #Check Sub-Dirs. under Products
        echo "-- Directories under Products --"
        ProductsPath="/var/www/magento2/pub/media/cache/products"
        Products="$ProductsPath/2 $ProductsPath/4 $ProductsPath/5 $ProductsPath/6 $ProductsPath/7 $ProductsPath/8 $ProductsPath/9 $ProductsPath/10 $ProductsPath/11 $ProductsPath/12 $ProductsPath/13 $ProductsPath/14"
        set -- $Products
        ProductsDirs=$@
        for i in "$@"
        do
                if [ -d $i ]; then
                        echo "Directory $i Exist."
                else echo "Directory $i DO NOT Exist" && Checklist=1
                fi
        done
        echo $Checklist
        echo \

        #Check JSON under Products
        echo "-- JSON Found under Products --"
        FILE=$ProductsPath/2/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/4/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/5/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/6/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/7/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/8/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/9/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/10/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/11/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/12/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/13/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        FILE=$ProductsPath/14/0.json; if [ -f $FILE ]; then echo "File $FILE Exist."; else echo "File $FILE DO NO Exist." && Checklist=1 && echo $Checklist; fi
        echo \

        #Total JSON Files Found under Products Dir
        echo "-- Total JSON Files Found under Products --"
        echo -n "StoreID 2 = "; find /var/www/magento2/pub/media/cache/products/2 -type f -name "*.json" | wc -l
        echo -n "StoreID 4 = "; find /var/www/magento2/pub/media/cache/products/4 -type f -name "*.json" | wc -l
        echo -n "StoreID 5 = "; find /var/www/magento2/pub/media/cache/products/5 -type f -name "*.json" | wc -l
        echo -n "StoreID 6 = "; find /var/www/magento2/pub/media/cache/products/6 -type f -name "*.json" | wc -l
        echo -n "StoreID 7 = "; find /var/www/magento2/pub/media/cache/products/7 -type f -name "*.json" | wc -l
        echo -n "StoreID 8 = "; find /var/www/magento2/pub/media/cache/products/8 -type f -name "*.json" | wc -l
        echo -n "StoreID 9 = "; find /var/www/magento2/pub/media/cache/products/9 -type f -name "*.json" | wc -l
        echo -n "StoreID 10 = "; find /var/www/magento2/pub/media/cache/products/10 -type f -name "*.json" | wc -l
        echo -n "StoreID 11 = "; find /var/www/magento2/pub/media/cache/products/11 -type f -name "*.json" | wc -l
        echo -n "StoreID 12 = "; find /var/www/magento2/pub/media/cache/products/12 -type f -name "*.json" | wc -l
        echo -n "StoreID 13 = "; find /var/www/magento2/pub/media/cache/products/13 -type f -name "*.json" | wc -l
        echo -n "StoreID 14 = "; find /var/www/magento2/pub/media/cache/products/14 -type f -name "*.json" | wc -l
        } #2>&1 | tee /tmp/check-json-script.log
        if [ $Checklist -eq 1 ]; then
                echo "JSON Generation is started." >> /tmp/check-json-script.log
				$(which mail) -s "JSON Generation Checklist" alert@example.com < /tmp/check-json.log -a From:"Example TV<no-reply@example.com>" > /dev/null 2>&1
                php /var/www/magento2/bin/magento ctv:json:generate
                /var/www/magento2/shell/swap_cache.sh
        fi	
fi
