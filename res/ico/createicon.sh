#!/bin/bash
svg=iconfinder_logo_brand_brands_logos_excel_2993694.svg
num=1
for size in 128 64 48 32 24 16 ; do
	rsvg -w $size -h $size  $svg opentsv_${num}_${size}x${size}x32.png
	num=$((num + 1))
done

icotool -c opentsv_*.png > tclkit.ico
