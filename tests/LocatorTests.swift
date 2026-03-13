import Testing
import Foundation
@testable import Playwright

extension PlaywrightTests {
	@Suite struct LocatorTests {
		// MARK: - Locator chaining, filtering, and composition

		@Test("locator.locator scopes to nested elements")
		func nestedLocator() async throws {
			try await withPage { page in
				try await page.setContent("<div><span>inner</span></div><span>outer</span>")
				let text = try await page.locator("div").locator("span").textContent()
				#expect(text == "inner")
			}
		}

		@Test("locator.first/last/nth select correct positional elements")
		func positionalLocators() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")
				let items = page.locator("li")
				#expect(try await items.first.textContent() == "A")
				#expect(try await items.last.textContent() == "C")
				#expect(try await items.nth(1).textContent() == "B")
			}
		}

		@Test("locator.filter narrows results by text content")
		func filterLocators() async throws {
			try await withPage { page in
				try await page.setContent("<div>Keep</div><div>Discard</div>")
				let count = try await page.locator("div").filter(hasText: "Keep").count()
				#expect(count == 1)
			}
		}

		@Test("locator.or matches either selector, locator.and matches both")
		func compositionLocators() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button class="primary">Submit</button>
						<a href="#">Link</a>
						<span>Neither</span>
					""")
				let orCount = try await page.locator("button").or(page.locator("a")).count()
				#expect(orCount == 2)

				let andCount = try await page.locator("button").and(page.locator(".primary")).count()
				#expect(andCount == 1)
			}
		}

		@Test("getByText with newlines matches multiline content")
		func getByTextMultiline() async throws {
			try await withPage { page in
				try await page.setContent("<pre>Line 1\nLine 2</pre>")
				let count = try await page.getByText("Line 1\nLine 2", exact: true).count()
				#expect(count == 1)
			}
		}

		// MARK: - getBy* integration tests

		@Test("getByLabel finds elements by associated label")
		func getByLabel() async throws {
			try await withPage { page in
				try await page.setContent("""
						<label for="email">Email address</label>
						<input id="email" type="email" />
					""")

				try await page.getByLabel("Email address").fill("test@example.com")
				let value = try await page.locator("#email").inputValue()
				#expect(value == "test@example.com")
			}
		}

		@Test("getByPlaceholder finds elements by placeholder text")
		func getByPlaceholder() async throws {
			try await withPage { page in
				try await page.setContent("<input placeholder='Enter your name' />")

				try await page.getByPlaceholder("Enter your name").fill("Alice")
				let value = try await page.locator("input").inputValue()
				#expect(value == "Alice")
			}
		}

		@Test("getByAltText finds elements by alt attribute")
		func getByAltText() async throws {
			try await withPage { page in
				try await page.setContent("<img alt='Company logo' src='data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==' />")

				let count = try await page.getByAltText("Company logo").count()
				#expect(count == 1)
			}
		}

		@Test("getByTitle finds elements by title attribute")
		func getByTitle() async throws {
			try await withPage { page in
				try await page.setContent("<span title='Close dialog'>X</span>")

				let text = try await page.getByTitle("Close dialog").textContent()
				#expect(text == "X")
			}
		}

		@Test("getByRole with checked option filters checkboxes")
		func getByRoleChecked() async throws {
			try await withPage { page in
				try await page.setContent("""
						<input type="checkbox" role="checkbox" aria-label="A" checked />
						<input type="checkbox" role="checkbox" aria-label="B" />
					""")

				let checked = try await page.getByRole(.checkbox, options: .init(checked: true)).count()
				#expect(checked == 1)
			}
		}

		@Test("getByRole with disabled option filters disabled elements")
		func getByRoleDisabled() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button disabled>Disabled</button>
						<button>Enabled</button>
					""")

				let disabled = try await page.getByRole(.button, options: .init(disabled: true)).count()
				#expect(disabled == 1)
			}
		}

		@Test("getByRole with level option filters headings")
		func getByRoleLevel() async throws {
			try await withPage { page in
				try await page.setContent("""
						<h1>Title</h1>
						<h2>Subtitle</h2>
						<h3>Section</h3>
					""")

				let h2 = try await page.getByRole(.heading, options: .init(level: 2)).count()
				#expect(h2 == 1)
			}
		}

		@Test("getByText with exact: true requires exact match")
		func getByTextExact() async throws {
			try await withPage { page in
				try await page.setContent("""
						<span>Hello World</span>
						<span>Hello</span>
					""")

				let exact = try await page.getByText("Hello", exact: true).count()
				#expect(exact == 1)
			}
		}

		// MARK: - Filtering

		@Test("filter(notHasText:) excludes elements with text")
		func filterHasNotText() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div class="item">Apple</div>
						<div class="item">Banana</div>
						<div class="item">Cherry</div>
					""")

				let count = try await page.locator(".item").filter(notHasText: "Banana").count()
				#expect(count == 2)
			}
		}

		@Test("filter(has:) filters by child locator presence")
		func filterHas() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div class="card"><h3>Card 1</h3></div>
						<div class="card"><p>Card 2</p></div>
						<div class="card"><h3>Card 3</h3></div>
					""")

				let withHeading = try page.locator(".card").filter(has: page.locator("h3"))
				let count = try await withHeading.count()
				#expect(count == 2)
			}
		}

		@Test("filter(hasNot:) filters by child locator absence")
		func filterHasNot() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div class="card"><h3>Card 1</h3></div>
						<div class="card"><p>Card 2</p></div>
						<div class="card"><h3>Card 3</h3></div>
					""")

				let withoutHeading = try page.locator(".card").filter(hasNot: page.locator("h3"))
				let count = try await withoutHeading.count()
				#expect(count == 1)
			}
		}

		// MARK: - Actions

		@Test("locator.click clicks a button")
		func clickButton() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button onclick="document.title = 'clicked'">Click me</button>
					""")

				try await page.locator("button").click()
				let title = try await page.title()
				#expect(title == "clicked")
			}
		}

		@Test("locator.fill fills an input field")
		func fillInput() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")

				let input = page.locator("input")
				try await input.fill("hello world")

				let value = try await input.inputValue()
				#expect(value == "hello world")
			}
		}

		@Test("locator.clear clears an input field")
		func clearInput() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' value='initial' />")

				let input = page.locator("input")
				try await input.clear()

				let value = try await input.inputValue()
				#expect(value == "")
			}
		}

		@Test("locator.check and uncheck work on checkboxes")
		func checkUncheck() async throws {
			try await withPage { page in
				try await page.setContent("<input type='checkbox' />")

				let checkbox = page.locator("input")
				try await checkbox.check()
				#expect(try await checkbox.isChecked())

				try await checkbox.uncheck()
				#expect(try await !checkbox.isChecked())
			}
		}

		@Test("locator.hover hovers over an element")
		func hoverElement() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div onmouseenter="document.title = 'hovered'" style="width:100px;height:100px">Hover me</div>
					""")

				try await page.locator("div").hover()
				let title = try await page.title()
				#expect(title == "hovered")
			}
		}

		@Test("locator.press presses a key")
		func pressKey() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")

				let input = page.locator("input")
				try await input.focus()
				try await input.press("a")

				let value = try await input.inputValue()
				#expect(value == "a")
			}
		}

		@Test("locator.selectOption selects a dropdown option")
		func selectOption() async throws {
			try await withPage { page in
				try await page.setContent("""
						<select>
							<option value="a">A</option>
							<option value="b">B</option>
						</select>
					""")

				try await page.locator("select").selectOption("b")
				let value = try await page.locator("select").inputValue()
				#expect(value == "b")
			}
		}

		@Test("locator.selectOption selects by visible label text")
		func selectOptionByLabel() async throws {
			try await withPage { page in
				try await page.setContent("""
						<select>
							<option value="us">United States</option>
							<option value="gb">United Kingdom</option>
						</select>
					""")

				try await page.locator("select").selectOption("United States")
				let value = try await page.locator("select").inputValue()
				#expect(value == "us")
			}
		}

		@Test("locator.focus and blur manage focus")
		func focusBlur() async throws {
			try await withPage { page in
				try await page.setContent("""
						<input id="input1" onfocus="document.title = 'focused'" onblur="document.title = 'blurred'" />
					""")

				let input = page.locator("#input1")
				try await input.focus()
				#expect(try await page.title() == "focused")

				try await input.blur()
				#expect(try await page.title() == "blurred")
			}
		}

		@Test("locator.dblclick double-clicks an element")
		func dblclick() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button ondblclick="document.title = 'dblclicked'">Double click me</button>
					""")

				try await page.locator("button").dblclick()
				let title = try await page.title()
				#expect(title == "dblclicked")
			}
		}

		@Test("locator.pressSequentially types text character by character")
		func pressSequentially() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' />")

				try await page.locator("input").pressSequentially("hello")
				let value = try await page.locator("input").inputValue()
				#expect(value == "hello")
			}
		}

		@Test("locator.setChecked sets checkbox to specific state")
		func setChecked() async throws {
			try await withPage { page in
				try await page.setContent("<input type='checkbox' />")

				let checkbox = page.locator("input")
				try await checkbox.setChecked(true)
				#expect(try await checkbox.isChecked())

				try await checkbox.setChecked(false)
				#expect(try await !checkbox.isChecked())

				try await checkbox.setChecked(true)
				#expect(try await checkbox.isChecked())
			}
		}

		// MARK: - Queries

		@Test("locator.textContent returns element text")
		func textContent() async throws {
			try await withPage { page in
				try await page.setContent("<p id='text'>Hello World</p>")

				let text = try await page.locator("#text").textContent()
				#expect(text == "Hello World")
			}
		}

		@Test("locator.innerHTML returns raw HTML")
		func innerHTML() async throws {
			try await withPage { page in
				try await page.setContent("<div id='container'><b>Bold</b></div>")

				let html = try await page.locator("#container").innerHTML()
				#expect(html == "<b>Bold</b>")
			}
		}

		@Test("locator.getAttribute returns attribute value")
		func getAttribute() async throws {
			try await withPage { page in
				try await page.setContent("<div id='test' data-value='42'>Test</div>")

				let value = try await page.locator("#test").getAttribute("data-value")
				#expect(value == "42")

				let missing = try await page.locator("#test").getAttribute("nonexistent")
				#expect(missing == nil)
			}
		}

		@Test("locator.isVisible checks element visibility")
		func isVisible() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div id="visible">Visible</div>
						<div id="hidden" style="display:none">Hidden</div>
					""")

				#expect(try await page.locator("#visible").isVisible())
				#expect(try await !page.locator("#hidden").isVisible())
				#expect(try await page.locator("#hidden").isHidden())
			}
		}

		@Test("locator.isEnabled checks element state")
		func isEnabled() async throws {
			try await withPage { page in
				try await page.setContent("""
						<input id="enabled" />
						<input id="disabled" disabled />
					""")

				#expect(try await page.locator("#enabled").isEnabled())
				#expect(try await page.locator("#disabled").isDisabled())
			}
		}

		@Test("locator.count returns number of matching elements")
		func count() async throws {
			try await withPage { page in
				try await page.setContent("<ul><li>A</li><li>B</li><li>C</li></ul>")

				let count = try await page.locator("li").count()
				#expect(count == 3)
			}
		}

		@Test("locator.innerText returns rendered text excluding hidden elements")
		func innerText() async throws {
			try await withPage { page in
				try await page.setContent("<div id='test'>Hello <span style='display:none'>hidden</span>World</div>")

				let text = try await page.locator("#test").innerText()
				#expect(text.contains("Hello"))
				#expect(text.contains("World"))
				#expect(!text.contains("hidden"))
			}
		}

		@Test("locator.isEditable checks if element is editable")
		func isEditable() async throws {
			try await withPage { page in
				try await page.setContent("""
						<input id="editable" />
						<input id="readonly" readonly />
					""")

				#expect(try await page.locator("#editable").isEditable())
				#expect(try await !page.locator("#readonly").isEditable())
			}
		}

		@Test("locator.isChecked returns checkbox state")
		func isCheckedQuery() async throws {
			try await withPage { page in
				try await page.setContent("""
						<input type="checkbox" id="checked" checked />
						<input type="checkbox" id="unchecked" />
					""")

				#expect(try await page.locator("#checked").isChecked())
				#expect(try await !page.locator("#unchecked").isChecked())
			}
		}

		@Test("locator.inputValue returns standalone input value")
		func inputValueStandalone() async throws {
			try await withPage { page in
				try await page.setContent("<input type='text' value='prefilled' />")

				let value = try await page.locator("input").inputValue()
				#expect(value == "prefilled")
			}
		}

		// MARK: - Screenshot options

		@Test("locator.screenshot with JPEG type")
		func locatorScreenshotJPEG() async throws {
			try await withPage { page in
				try await page.setContent("<div id='target' style='width:100px;height:100px;background:blue'>Box</div>")
				let data = try await page.locator("#target").screenshot(type: .jpeg, quality: 80)
				#expect(!data.isEmpty)
				// JPEG magic bytes
				#expect(data[0] == 0xFF)
				#expect(data[1] == 0xD8)
			}
		}

		// MARK: - Error cases

		@Test("click on nonexistent selector throws elementNotFound")
		func clickNonexistent() async throws {
			try await withPage { page in
				try await page.setContent("<div>Empty</div>")
				await #expect {
					try await page.locator(".nonexistent").click(timeout: .seconds(2))
				} throws: { error in
					guard case PlaywrightError.elementNotFound = error else { return false }
					return true
				}
			}
		}

		@Test("strict mode violation throws when multiple elements match")
		func strictModeViolation() async throws {
			try await withPage { page in
				try await page.setContent("<button>A</button><button>B</button>")
				await #expect {
					try await page.locator("button").click(timeout: .seconds(2))
				} throws: { error in
					guard case let PlaywrightError.elementNotFound(msg) = error else { return false }
					return msg.lowercased().contains("strict mode violation")
				}
			}
		}

		@Test("count returns 0 for non-matching selector")
		func countZero() async throws {
			try await withPage { page in
				try await page.setContent("<div>Nothing matches</div>")
				let count = try await page.locator(".nonexistent").count()
				#expect(count == 0)
			}
		}

		@Test("isVisible returns false for non-matching selector")
		func isVisibleNonexistent() async throws {
			try await withPage { page in
				try await page.setContent("<div>Content</div>")
				let visible = try await page.locator(".nonexistent").isVisible()
				#expect(!visible)
			}
		}

		@Test("textContent returns empty string on empty element")
		func textContentEmpty() async throws {
			try await withPage { page in
				try await page.setContent("<span id='empty'></span>")
				let text = try await page.locator("#empty").textContent()
				#expect(text == "")
			}
		}

		// MARK: - Locator composition errors

		@Test("or throws invalidArgument for cross-frame locators")
		func orCrossFrame() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()
				let a = page1.locator("div")
				let b = page2.locator("span")
				#expect {
					_ = try a.or(b)
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("and throws invalidArgument for cross-frame locators")
		func andCrossFrame() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()
				#expect {
					_ = try page1.locator("div").and(page2.locator("span"))
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("filter(has:) throws invalidArgument for cross-frame locators")
		func filterHasCrossFrame() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()
				#expect {
					_ = try page1.locator("div").filter(has: page2.locator("span"))
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("filter(hasNot:) throws invalidArgument for cross-frame locators")
		func filterHasNotCrossFrame() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()
				#expect {
					_ = try page1.locator("div").filter(hasNot: page2.locator("span"))
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		@Test("locator(_ locator:) chains with internal:chain selector")
		func locatorLocatorOverload() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div class="outer">
							<span class="inner">Found</span>
						</div>
					""")
				let outer = page.locator(".outer")
				let inner = page.locator(".inner")
				let chained = try outer.locator(inner)
				#expect(chained.selector.contains("internal:chain="))
				let text = try await chained.textContent()
				#expect(text == "Found")
			}
		}

		@Test("locator(_ locator:) throws for cross-frame locators")
		func locatorLocatorCrossFrame() async throws {
			try await withContext { context in
				let page1 = try await context.newPage()
				let page2 = try await context.newPage()
				#expect {
					_ = try page1.locator("div").locator(page2.locator("span"))
				} throws: { error in
					guard case PlaywrightError.invalidArgument = error else { return false }
					return true
				}
			}
		}

		// MARK: - Action options

		@Test("click with right button triggers contextmenu")
		func clickRightButton() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div id="target" oncontextmenu="document.title = 'contextmenu'; return false;" style="width:100px;height:100px">
							Right click me
						</div>
					""")
				try await page.locator("#target").click(button: .right)
				let title = try await page.title()
				#expect(title == "contextmenu")
			}
		}

		@Test("click with shift modifier passes modifier key")
		func clickWithModifier() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button onclick="document.title = event.shiftKey ? 'shift' : 'no-shift'">Click</button>
					""")
				try await page.locator("button").click(modifiers: [.shift])
				let title = try await page.title()
				#expect(title == "shift")
			}
		}

		@Test("click with position clicks at specific coordinates")
		func clickWithPosition() async throws {
			try await withPage { page in
				try await page.setContent("""
						<div id="target" style="width:200px;height:200px"
							onclick="document.title = Math.round(event.offsetX) + ',' + Math.round(event.offsetY)">
						</div>
					""")
				try await page.locator("#target").click(position: Position(x: 10, y: 20))
				let title = try await page.title()
				#expect(title == "10,20")
			}
		}

		@Test("selectOption with array selects multiple options")
		func selectOptionMultiple() async throws {
			try await withPage { page in
				try await page.setContent("""
						<select multiple>
							<option value="a">A</option>
							<option value="b">B</option>
							<option value="c">C</option>
						</select>
					""")
				try await page.locator("select").selectOption(["a", "c"])
				let selected: [String] = try await page.evaluate("""
						Array.from(document.querySelector('select').selectedOptions).map(o => o.value)
					""")
				#expect(selected.contains("a"))
				#expect(selected.contains("c"))
				#expect(!selected.contains("b"))
			}
		}

		// MARK: - getBy* integration

		@Test("getByTestId finds element by data-testid")
		func getByTestId() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button data-testid="submit-btn">Submit</button>
					""")
				let text = try await page.getByTestId("submit-btn").textContent()
				#expect(text == "Submit")
			}
		}

		@Test("getByRole without options finds elements by role")
		func getByRoleNoOptions() async throws {
			try await withPage { page in
				try await page.setContent("<button>Click me</button>")
				let count = try await page.getByRole(.button).count()
				#expect(count == 1)
			}
		}

		@Test("getByRole with name finds element by accessible name")
		func getByRoleWithName() async throws {
			try await withPage { page in
				try await page.setContent("""
						<button>Submit</button>
						<button>Cancel</button>
					""")
				let submit = try await page.getByRole(.button, options: .init(name: "Submit")).count()
				#expect(submit == 1)
			}
		}

		// MARK: - Page reference

		@Test("locator.page returns the owning page")
		func locatorPage() async throws {
			try await withPage { page in
				let locator = page.locator("body")
				#expect(locator.page === page)
			}
		}

		@Test("chained locator.page is the same page")
		func chainedLocatorPage() async throws {
			try await withPage { page in
				let child = page.locator("div").locator("span")
				#expect(child.page === page)
			}
		}
	}
}
