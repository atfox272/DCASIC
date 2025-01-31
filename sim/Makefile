.PHONY: all step1 step2 step3

all: input_gen sim output_anal

input_gen:
	python dut_env/dut_input/img2txt.py

sim:
	$(MAKE) -f tool_run

output_anal:
	python dut_env/dut_output/txt2img.py