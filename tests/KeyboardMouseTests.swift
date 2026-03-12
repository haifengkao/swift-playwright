import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct KeyboardMouseTests {
		// MARK: - Keyboard

		@Test("keyboard.type types text into focused input")
		func keyboardType() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")
				try await page.locator("input").focus()
				try await page.keyboard.type("hello")
				let value = try await page.locator("input").inputValue()
				#expect(value == "hello")
			}
		}

		@Test("keyboard.press presses Enter key")
		func keyboardPressEnter() async throws {
			try await withPage { page in
				try await page.setContent("""
					<input type='text' onkeydown="if(event.key==='Enter') document.title='enter'" />
				""")
				try await page.locator("input").focus()
				try await page.keyboard.press("Enter")
				let title = try await page.title()
				#expect(title == "enter")
			}
		}

		@Test("keyboard.down + press + up types uppercase with Shift")
		func keyboardShiftCombo() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")
				try await page.locator("input").focus()
				try await page.keyboard.down("Shift")
				try await page.keyboard.press("KeyA")
				try await page.keyboard.up("Shift")
				let value = try await page.locator("input").inputValue()
				#expect(value == "A")
			}
		}

		@Test("keyboard.insertText inserts text without key events")
		func keyboardInsertText() async throws {
			try await withPage { page in
				try await page.setContent("""
					<input type='text' onkeydown="document.title='keydown'" />
				""")
				try await page.locator("input").focus()
				try await page.keyboard.insertText("hello")
				let value = try await page.locator("input").inputValue()
				#expect(value == "hello")
				// insertText should NOT trigger keydown
				let title = try await page.title()
				#expect(title != "keydown")
			}
		}

		// MARK: - Mouse

		@Test("mouse.click clicks at page coordinates")
		func mouseClick() async throws {
			try await withPage { page in
				try await page.setContent("""
					<button style="position:absolute;left:0;top:0;width:100px;height:100px"
						onclick="document.title='clicked'">Click</button>
				""")
				try await page.mouse.click(x: 50, y: 50)
				let title = try await page.title()
				#expect(title == "clicked")
			}
		}

		@Test("mouse.dblclick fires double-click event")
		func mouseDblclick() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div style="position:absolute;left:0;top:0;width:100px;height:100px"
						ondblclick="document.title='dblclicked'">Target</div>
				""")
				try await page.mouse.dblclick(x: 50, y: 50)
				let title = try await page.title()
				#expect(title == "dblclicked")
			}
		}

		@Test("mouse.move triggers mousemove events")
		func mouseMove() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div style="position:absolute;left:0;top:0;width:200px;height:200px"
						onmousemove="document.title='moved'">Target</div>
				""")
				try await page.mouse.move(x: 100, y: 100)
				let title = try await page.title()
				#expect(title == "moved")
			}
		}

		@Test("mouse.down and mouse.up dispatch individual events")
		func mouseDownUp() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div style="position:absolute;left:0;top:0;width:100px;height:100px"
						id="target">Target</div>
					<script>
						const t = document.getElementById('target');
						const log = [];
						t.addEventListener('mousedown', () => log.push('down'));
						t.addEventListener('mouseup', () => log.push('up'));
						window._log = log;
					</script>
				""")
				try await page.mouse.move(x: 50, y: 50)
				try await page.mouse.down()
				try await page.mouse.up()
				let log: [String] = try await page.evaluate("window._log")
				#expect(log == ["down", "up"])
			}
		}

		@Test("mouse.click with right button fires contextmenu")
		func mouseRightClick() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div style="position:absolute;left:0;top:0;width:100px;height:100px"
						id="target">Target</div>
					<script>
						document.getElementById('target').addEventListener('contextmenu', () => {
							document.title = 'rightclicked';
						});
					</script>
				""")
				try await page.mouse.click(x: 50, y: 50, button: .right)
				let title = try await page.title()
				#expect(title == "rightclicked")
			}
		}

		@Test("mouse.wheel scrolls the page")
		func mouseWheel() async throws {
			try await withPage { page in
				try await page.setContent("""
					<div style="height:5000px">Tall page</div>
					<script>
						window.addEventListener('wheel', () => document.title = 'scrolled');
					</script>
				""")
				try await page.mouse.wheel(deltaX: 0, deltaY: 100)
				// Give the event time to fire
				try await page.waitForTimeout(.milliseconds(100))
				let title = try await page.title()
				#expect(title == "scrolled")
			}
		}
	}
}
