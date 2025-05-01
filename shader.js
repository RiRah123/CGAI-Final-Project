// Initialize WebGL
function initWebGL() {
    const canvas = document.getElementById('glCanvas');
    const gl = canvas.getContext('webgl');

    if (!gl) {
        alert('WebGL not supported');
        return;
    }

    // Create shader program
    function createShader(gl, type, source) {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            console.error('Shader compile error:', gl.getShaderInfoLog(shader));
            gl.deleteShader(shader);
            return null;
        }
        return shader;
    }

    // Load shader code
    async function loadShader() {
        try {
            const response = await fetch('shader.glsl');
            const fragmentShaderSource = await response.text();
            
            // Create program
            const vertexShader = createShader(gl, gl.VERTEX_SHADER, `
                attribute vec2 position;
                void main() {
                    gl_Position = vec4(position, 0.0, 1.0);
                }
            `);

            const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);

            const program = gl.createProgram();
            gl.attachShader(program, vertexShader);
            gl.attachShader(program, fragmentShader);
            gl.linkProgram(program);

            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
                console.error('Program link error:', gl.getProgramInfoLog(program));
                return;
            }

            // Create buffer
            const buffer = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
            gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
                -1, -1,
                1, -1,
                -1, 1,
                1, 1
            ]), gl.STATIC_DRAW);

            // Get uniform locations
            const resolutionLocation = gl.getUniformLocation(program, 'iResolution');
            const timeLocation = gl.getUniformLocation(program, 'iTime');
            const mouseLocation = gl.getUniformLocation(program, 'iMouse');

            // Mouse position
            let mouseX = 0;
            let mouseY = 0;
            let mouseZ = -1;

            canvas.addEventListener('mousemove', (e) => {
                const rect = canvas.getBoundingClientRect();
                mouseX = e.clientX - rect.left;
                mouseY = e.clientY - rect.top;
                mouseZ = 1;
            });

            canvas.addEventListener('mouseup', () => {
                mouseZ = -1;
            });

            // Animation loop
            function render() {
                // Resize canvas
                const displayWidth = canvas.clientWidth;
                const displayHeight = canvas.clientHeight;
                if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
                    canvas.width = displayWidth;
                    canvas.height = displayHeight;
                    gl.viewport(0, 0, canvas.width, canvas.height);
                }

                // Use program
                gl.useProgram(program);

                // Set uniforms
                gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
                gl.uniform1f(timeLocation, performance.now() / 1000);
                gl.uniform3f(mouseLocation, mouseX, mouseY, mouseZ);

                // Set attributes
                const positionLocation = gl.getAttribLocation(program, 'position');
                gl.enableVertexAttribArray(positionLocation);
                gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

                // Draw
                gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

                // Next frame
                requestAnimationFrame(render);
            }

            // Start animation
            render();
        } catch (error) {
            console.error('Error loading shader:', error);
        }
    }

    // Start loading the shader
    loadShader();
}

// Initialize WebGL when the page loads
window.addEventListener('load', initWebGL); 