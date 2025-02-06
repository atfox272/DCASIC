.PHONY: all step1 step2 step3

all: pre_sim input_gen sim output_anal

pre_sim:
	if [ ! -f dut_env/dut_output/img_txt.txt ]; then echo "Creating img_txt.txt" > dut_env/dut_output/img_txt.txt; fi

input_gen:
	python dut_env/dut_input/img2txt.py

sim:
	$(MAKE) -f tool_run

output_anal:
	python dut_env/dut_output/txt2img.py

clean:
	del /f dut_env\dut_input\img_txt.txt dut_env\dut_output\img_txt.txt
	