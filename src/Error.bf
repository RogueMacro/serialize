using System;
using Serialize.Implementation;
using internal Serialize.Implementation;

namespace Serialize
{
	class DeserializeError
	{
		public String Message ~ delete _;
		public int Line;
		public int Position;
		public int Length;

		public int CharactersAround = 10;

		private String _lineText ~ delete _;

		public this(String message, IDeserializer deserializer, int length = 1, int position = -1)
		{
			Message = message;

			let reader = deserializer.Reader;
			if (reader.Length == 0)
			{
				Line = 0;
				Position = 0;
				Length = 1;
				_lineText = new .();
				CharactersAround = 0;
				return;
			}

			var position;
			position = (position < 0 ? reader.Position : position);
			position = Math.Clamp(position, 0, reader.Length - 1);

			Line = reader.LineNumberAt(position);
			Position = position - reader.[Friend]IndexOfReverse('\n', position) - 1;
			Length = length;

			_lineText = reader.ReadLineAt(position, .. new .());
			Position += 3 * _lineText.Count('\t');
			_lineText.Replace("\t", "    ");

			if (_lineText.Length - Position - Length > CharactersAround)
				_lineText.RemoveToEnd(Position + Length + CharactersAround);

			if (Position > CharactersAround)
			{
				_lineText.Remove(0, Position - CharactersAround);
				Position = CharactersAround;
			}
		}

		public override void ToString(String strBuffer)
		{
			let lineNumberStr = Line.ToString(.. scope .());
			String lineNumberEmpty = scope .();
			for (int _ = 0; _ < lineNumberStr.Length; _++)
				lineNumberEmpty.Append(' ');

			String underline = scope .();
			for (int i = 0; i < Position + Length; i++)
			{
				if (i < Position)
					underline.Append(' ');
				else
					underline.Append('^');
			}

			strBuffer.Append(
				scope $"""
				{Message}
				{lineNumberEmpty} |
				{Line} | {_lineText}
				{lineNumberEmpty} | {underline}
				""");
		}
	}

	enum FieldDeserializeError
	{
		DeserializationError,
		UnknownField
	}
}