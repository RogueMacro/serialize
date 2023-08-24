using System;
using System.Collections;
using System.Reflection;
using Serialize;
using Serialize.Implementation;
using Serialize.Util;

namespace System
{
	extension Variant : ISerializable, ISerializeAsPrimitive
	{
		Type ISerializable.__SerializeActualType => VariantType;

		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			if (mStructType == 2)
			{
				serializer.SerializeNull();
				return;
			}

			switch (VariantType)
			{
			case typeof(bool): Serialize!<bool>();
			case typeof(int): Serialize!<int>();
			case typeof(uint): Serialize!<uint>();
			case typeof(float): Serialize!<float>();
			case typeof(double): Serialize!<double>();
			case typeof(Boolean): Serialize!<Boolean>();
			case typeof(Int): Serialize!<Int>();
			case typeof(UInt): Serialize!<UInt>();
			case typeof(Float): Serialize!<Float>();
			case typeof(Double): Serialize!<Double>();
			case typeof(String): Serialize!<String>();
			case typeof(DateTime): Serialize!<DateTime>();
			case typeof(List<Variant>): Serialize!<List<Variant>>();
			case typeof(Dictionary<String, Variant>): Serialize!<Dictionary<String, Variant>>();
			default: Runtime.FatalError(scope $"Unsupported type {VariantType}");
			}

			mixin Serialize<T>() where T : var
			{
				Get<T>().Serialize(serializer);
				break;
			}
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			let pos = deserializer.Reader.Position;

			TryDeserialize!<bool>();
			TryDeserialize!<int>();
			TryDeserialize!<uint>();
			TryDeserialize!<float>();
			TryDeserialize!<double>();
			TryDeserialize!<String>();
			TryDeserialize!<DateTime>();
			TryDeserialize!<List<Variant>>();
			TryDeserialize!<Dictionary<String, Variant>>();

			if (deserializer.DeserializeNull())
				return Self.Create<String>(null);

			return .Err;

			mixin TryDeserialize<T>() where T : var, struct
			{
				let pos = deserializer.Reader.Position;
				if (T.Deserialize(deserializer) case .Ok(let val))
					return Self.Create(val);
				deserializer.Reader.Position = pos;
			}

			mixin TryDeserialize<T>() where T : var, class
			{
				if (T.Deserialize(deserializer) case .Ok(let val))
					return Self.Create(val, true);
				deserializer.Reader.Position = pos;
			}
		}

		public new void Dispose() mut
		{
			if (VariantType == typeof(List<Variant>))
				ClearAndDisposeItems!(Get<List<Variant>>());
			else if (VariantType == typeof(Dictionary<String, Variant>))
			{
				for (var (key, value) in Get<Dictionary<String, Variant>>())
				{
					delete key;
					value.Dispose();
				}
			}

			base.Dispose();
		}
	}
}
