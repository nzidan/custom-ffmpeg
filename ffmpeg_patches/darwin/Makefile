output = "test_compat"
sources = $(wildcard *.m) $(wildcard include/*.m)

build:
	@clang -framework Foundation -framework AVFoundation -framework CoreAudio -Wall ${sources} -o ${output}

clean:
	@rm ${output}

run:
	@make build
	@./${output}
