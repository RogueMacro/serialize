using System;
using System.IO;

namespace Serialize.Implementation
{
	class Reader
	{
		public int Position { get; private set; }
		public int Length => _content.Length;

		public bool EOF => Position >= _content.Length;

		private StringView _content;

		public this(StringView content)
		{
			_content = content;
		}

		public Result<char8> Peek(int offset = 0) => EOF ? .Err : .Ok(_content.Slice(Position + offset, 1)[0]);

		public Result<char8> Read()
		{
			Result<char8> char = Peek();
			Position++;
			return char;
		}

		public int LineNumberAt(int position)
		{
			int lines = 0;
			for (_content.Substring(0, position).Split('\n'))
				lines++;
			return lines;
		}

		public void ReadLineAt(int position, String str)
		{
			int lineStart = IndexOfReverse('\n', position);
			lineStart = lineStart == -1 ? 0 : lineStart + 1;

			int lineEnd = _content.IndexOf('\n', position);
			lineEnd = lineEnd == -1 ? _content.Length : lineEnd;

			int length = lineEnd - lineStart;

			str.Append(_content.Substring(lineStart, length));
		}

		int IndexOfReverse(char8 c, int startIdx)
		{
			let ptr = _content.Ptr;
			for (int i = startIdx - 1; i >= 0; i--)
				if (ptr[i] == c)
					return i;
			return -1;
		}
	}
}