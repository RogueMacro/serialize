using System;
using System.Collections;
using System.IO;

namespace Serialize.Implementation
{
	interface IDeserializer
	{
		Reader Reader { get; set; }

		DeserializeError Error { get; set; }
		void SetError(DeserializeError error);

		void PushState();
		void PopState();

		Result<void> DeserializeStructStart(int size);
		Result<void> DeserializeStructEnd();
		Result<void, FieldDeserializeError> DeserializeStructField(
			delegate Result<void, FieldDeserializeError>(StringView field) deserialize,
			Span<StringView> fieldsLeft,
			bool first);

		Result<Dictionary<TKey, TValue>> DeserializeMap<TKey, TValue>()
			where TKey : ISerializableKey
			where TValue : ISerializable;

		Result<List<T>> DeserializeList<T>()
			where T : ISerializable;

		Result<String> DeserializeString();

		Result<int> DeserializeInt();
		Result<int8> DeserializeInt8() => DeserializeClamp<int8, int>(scope => DeserializeInt, int8.MinValue, int8.MaxValue);
		Result<int16> DeserializeInt16() => DeserializeClamp<int16, int>(scope => DeserializeInt, int16.MinValue, int16.MaxValue);
		Result<int32> DeserializeInt32() => DeserializeClamp<int32, int>(scope => DeserializeInt, int32.MinValue, int32.MaxValue);
		Result<int64> DeserializeInt64() => DeserializeClamp<int64, int>(scope => DeserializeInt, int64.MinValue, int64.MaxValue);

		Result<uint> DeserializeUInt();
		Result<uint8> DeserializeUInt8() => DeserializeClamp<uint8, uint>(scope => DeserializeUInt, uint8.MinValue, uint8.MaxValue);
		Result<uint16> DeserializeUInt16() => DeserializeClamp<uint16, uint>(scope => DeserializeUInt, uint16.MinValue, uint16.MaxValue);
		Result<uint32> DeserializeUInt32() => DeserializeClamp<uint32, uint>(scope => DeserializeUInt, uint32.MinValue, uint32.MaxValue);
		Result<uint64> DeserializeUInt64() => DeserializeClamp<uint64, uint>(scope => DeserializeUInt, uint64.MinValue, uint64.MaxValue);

		Result<double> DeserializeDouble();
		Result<float> DeserializeFloat() => DeserializeClamp<float, double>(scope => DeserializeDouble, float.MinValue, float.MaxValue);

		Result<DateTime> DeserializeDateTime();

		Result<bool> DeserializeBool();

		bool DeserializeNull();

		/// Convert the parsed integer and cast it to the actual target type.
		/// Ensures that the value is not larger than what the target type can hold.
		Result<TTo> DeserializeClamp<TTo, TFrom>(delegate Result<TFrom>() deserialize, TFrom min, TFrom max)
			where TTo : operator explicit TFrom
			where bool : operator TFrom < TFrom
		{
			int start = Reader.Position;

			TFrom i = Try!(deserialize());

			if (i < min || i > max)
			{
				int end = Reader.Position;
				SetError(new .(new $"Number is too large for type {typeof(TTo).GetName(.. scope .())}", this, start, end - start));
				return .Err;
			}

			return (TTo)i;
		}
	}
}