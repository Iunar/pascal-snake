{ Ideas }
{
	Change camera position to improve readability
	Store highscores
	Highscore names
	3D snake (3D grid)
	Multiple grids, move through the border on one of the four sides
	to move the the next grid.
	+--+ +--+ +--+
	|  | |  | |  |
	+--+ +--+ +--+
	+--+ +--+ +--+
	|  | |  | |  |
	+--+ +--+ +--+
	+--+ +--+ +--+
	|  | |  | |  |
	+--+ +--+ +--+
}

program pascal_snake;

{ 
	$MODE objfpc  Compiler mode for adding oop (vomit) 
	a ansistring is a heap allocated, null-terminated string, that is reference counted.
	a shortstring is a stack allocated string whose first byte represents the length of the string.
		since it is one byte, a shortstring can only hold 255 chars.
	a unicodestring is a ansistring in every way except for the fact that each char is wide.
	a widestring is the same as a unicode string on every os other than windows, on windows the
		only difference is that it is not reference counted.
	a PChar is a pointer to a array of characters on the heap that could be null-terminated. 
		In other words, a cstring.
	Useful link for string sizes: https://www.freepascal.org/docs-html/3.2.0/ref/refsu13.html.
}
{$MODE fpc} { Tell the compiler to switch to the FPC(default) mode }
{$UNITPATH raylib} { Tell the compiler to include the raylib directroy when searching for units (this shit rocks) }
{$LIBRARYPATH raylib} { Tell the compiler to include the raylib directory when searching for libraries (this shit rocks) }

uses cmem, raylib, math, Sysutils;

const
	GREY_PURPLE: 					TColor = (r: 32; g: 30; b: 33; a: 255);
	LIGHT_GREEN: 					TColor = (r: 176; g: 237; b: 71; a: 255;);
	main_frame_buffer_width: 		integer = 320;
	main_frame_buffer_height: 		integer = 240;
	main_frame_buffer_render_scale: real = 3.25;

var
	i:								integer;
	running:						boolean = true;
	camera:							TCamera3D;
	main_frame_buffer:				TRenderTexture2D;
	score:							integer = 0;
	score_step:						integer = 10;
	score_max:						integer = 0;
	apple:							TVector3;
	snake:							array of TVector3;
	snake_end:						integer = 0;
	snake_vector:					TVector2;
	snake_move_interval_s:			real = 0.25;
	grid_size:						integer = 16;
	snake_movement_timer_start:					real = 0.0;

procedure display_main_frame_buffer;
begin
	BeginDrawing();
		DrawTexturePro(
			main_frame_buffer.Texture,
			RectangleCreate(0, 0, main_frame_buffer_width, main_frame_buffer_width),
			RectangleCreate(
				0, 0, 
				main_frame_buffer_width * main_frame_buffer_render_scale,
				main_frame_buffer_width * main_frame_buffer_render_scale
			),
			Vector2Create(0, 0),
			0, WHITE
		);

		{ Overlays }
		DrawFPS(0, 0);
		DrawText(PChar(FloatToStr(GetTime())), 0, 24, 20, WHITE);
		DrawText(
			PChar(Format('<%s, %s>', [PChar(FloatToStr(snake_vector.x)), PChar(FloatToStr(snake_vector.y))])),
			0, 48, 20, WHITE
		);
		DrawText(
			PChar(Format('Score: %d', [score])), 0, 64, 20, YELLOW
		);
		DrawText(
			PChar(Format('snake: <%n, %n, %n>', [snake[0].x, snake[0].y, snake[0].z])), 
			0, 88, 20, GREEN
		);
		DrawText(
			PChar(Format('apple: <%n, %n>', [apple.x, apple.y])),
			0, 102, 20, RED
		);
		DrawText(
			PChar(Format('snake_end: %d', [snake_end])),
			0, 126, 20, RED
		);

	EndDrawing();
end;

procedure draw_game_over;
var should_game_over_menu_close: boolean = false;
begin
	while not should_game_over_menu_close do
	begin
		if IsKeyPressed(KEY_Q) or IsKeyPressed(KEY_ESCAPE) or WindowShouldClose() then
		begin
			should_game_over_menu_close := true;
			running := false;
		end;

		{ TODO: implement restart option }

		BeginDrawing();
			ClearBackground(GREY_PURPLE);
			DrawText('You fucking suck, shitter!', 0, 0, 20, WHITE);
			DrawText(PChar(Format('Final Score: %d', [score])), 0, 24, 20, WHITE);
			DrawText('Press "q" or escape to quit.', 0, 48, 20, RED);
			DrawText('Press "r" to retry.', 0, 72, 20, GREEN);
		EndDrawing();
	end;
end;

begin
	InitWindow(
		Trunc(main_frame_buffer_width * main_frame_buffer_render_scale),
		Trunc(main_frame_buffer_height * main_frame_buffer_render_scale),
	 	'[Program]');
	SetTargetFPS(60);

	{ Set up the camera }
	camera := Default(TCamera3D);
	camera.Fovy := 45;
	camera.Up := Vector3Create(0, 1, 0);
	camera.Position := Vector3Create(0, -15, -15);
	camera.Target := Vector3Create(0, 0, 0);
	camera.Projection := CAMERA_PERSPECTIVE;

	{ Set up the down scaled frame buffer }
	main_frame_buffer := LoadRenderTexture(main_frame_buffer_width, main_frame_buffer_height);

	{ Initialize variables }
	score_max := grid_size * grid_size;
	apple := Vector3Create(7.5 - Random(grid_size), -0.5, 7.5 - Random(grid_size));
	setLength(snake, grid_size * grid_size);
	snake[snake_end] := Vector3Create(7.5, -0.5, 7.5);
	snake_end := snake_end + 1;
	snake_movement_timer_start := GetTime();

	while running do
	begin
		{ Handle quiting }
		if IsKeyPressed(KEY_Q) or IsKeyPressed(KEY_ESCAPE) or WindowShouldClose() or (score = score_max) then
			running := false;

		{ Snake Input }
		if IsKeyPressed(KEY_W) then
			snake_vector := Vector2Create(0, 1)
		else if IsKeyPressed(KEY_S) then
			snake_vector := Vector2Create(0, -1);
		if IsKeyPressed(KEY_A) then
			snake_vector := Vector2Create(1, 0)
		else if IsKeyPressed(KEY_D) then
			snake_vector := Vector2Create(-1, 0);
		if IsKeyPressed(KEY_SPACE) then
			snake_vector := Vector2Create(0, 0);

		{ Update Snake Position }
		if (GetTime() - snake_movement_timer_start) >= snake_move_interval_s then
		begin
			{ Update the snake's body }
			if snake_end > 1 then
			begin
				for i := snake_end - 1 downto 1 do
					snake[i] := snake[i - 1];
			end;
			
			{ Move the snake }
			snake[0].x := snake[0].x + snake_vector.x;
			snake[0].z := snake[0].z + snake_vector.y;

			{ Snake Wrapping }
			if snake[0].x > (grid_size / 2.0) then
				snake[0].x := -(grid_size / 2.0) + 0.5
			else if snake[0].x < -(grid_size / 2.0) then
				snake[0].x := (grid_size / 2.0) - 0.5;
			if snake[0].z > (grid_size / 2.0) then
				snake[0].z := -(grid_size / 2.0) + 0.5
			else if snake[0].z < -(grid_size / 2.0) then
				snake[0].z := (grid_size / 2.0) - 0.5;

			{ Check for collisions on the snakes body }
			for i := 1 to snake_end - 1 do
				if (snake[0].x = snake[i].x) and (snake[0].z = snake[i].z) then
				begin
					draw_game_over();
				end;

			{ Restart the movement timer }
			snake_movement_timer_start := GetTime();
		end;


		{ Apple Update }
		if (snake[0].x = apple.x) and (snake[0].z = apple.z) then
		begin
			score := score + score_step;
			snake[snake_end] := snake[snake_end - 1];
			snake_end := snake_end + 1;
			{ apple := Vector3Create(7.5 - Random(grid_size), 0, 7.5 - Random(grid_size)); }

			{ Prevent apple from spawning inside the snake's body }
			i := 0;
			while true do
			begin
				if i >= snake_end then break;
				if (snake[i].x = apple.x) and (snake[i].z = apple.z) then
				begin
					apple := Vector3Create(7.5 - Random(grid_size), -0.5, 7.5 - Random(grid_size));
					i := 0;
				end
				else 
					i := i + 1;
			end;
		end;

		BeginTextureMode(main_frame_buffer);
			BeginMode3D(camera);
				ClearBackground(GREY_PURPLE);
				DrawCube(apple, 1, 1, 1, RED);
				DrawGrid(16, 1);
				for i := 0 to snake_end - 1 do 
				begin
					if i mod 2 = 0 then
						DrawCube(snake[i], 1, 1, 1, LIGHT_GREEN)
					else
						DrawCube(snake[i], 1, 1, 1, GREEN);
				end;
			EndMode3D();
		EndTextureMode();

		display_main_frame_buffer();
  	end;

  	CloseWindow();
end.
