using System;
using Serialize.Implementation;

namespace Serialize
{
	/// Automatically implemented by the [Serializable] attribute.
	interface ISerializable
	{
		void Serialize<S>(S serializer)
			where S : ISerializer;

		static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer;
	}

	interface ISerializableKey : ISerializable, IHashable
	{
		void ToKey(String buffer);

		static Result<Self> Parse(StringView str);
	}
}

namespace System
{
	using Serialize;

	extension Nullable<T> : ISerializable
		where T : ISerializable
	{
		public void Serialize<S>(S serializer) where S : ISerializer
		{
			if (HasValue)
				Value.Serialize(serializer);
			else
				serializer.SerializeNull();
		}

		public static Result<Self> Deserialize<D>(D deserializer) where D : IDeserializer
		{
			if (deserializer.DeserializeNull())
			{
				return null;
			}
            else
			{
				T val = (.)Try!(T.Deserialize(deserializer));
				return Nullable<T>(val);
			}

			//return .Ok;
		}
	}

	extension String : ISerializableKey
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeString(this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return deserializer.DeserializeString();
		}

		public void ToKey(String buffer)
		{
			buffer.Append(this);
		}

		public static Result<String> Parse(StringView str)
		{
			return new String(str);
		}
	}

	extension Boolean : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeBool((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeBool());
		}
	}

	extension DateTime : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeDateTime(this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return deserializer.DeserializeDateTime();
		}
	}

#region Numbers
	extension Int : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt());
		}
	}

	extension Int8 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt8());
		}
	}

	extension Int16 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt16());
		}
	}

	extension Int32 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt16());
		}
	}

	extension Int64 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeInt16());
		}
	}

	extension UInt : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeUInt((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeUInt());
		}
	}

	extension UInt8 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeUInt8((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeUInt8());
		}
	}

	extension UInt16 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeUInt16((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeUInt16());
		}
	}

	extension UInt32 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeUInt32((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeUInt32());
		}
	}

	extension UInt64 : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeUInt64((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeUInt64());
		}
	}

	extension Float : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeFloat((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeFloat());
		}
	}

	extension Double : ISerializable
	{
		public void Serialize<S>(S serializer)
			where S : ISerializer
		{
			serializer.SerializeDouble((.)this);
		}

		public static Result<Self> Deserialize<D>(D deserializer)
			where D : IDeserializer
		{
			return Try!(deserializer.DeserializeDouble());
		}
	}
#endregion

	namespace Collections
	{
		extension Dictionary<TKey, TValue> : ISerializable
			where TKey : ISerializableKey
			where TValue : ISerializable
		{
			public void Serialize<S>(S serializer)
				where S : ISerializer
			{
				serializer.SerializeMapStart(Count);
				bool first = true;
				for (let (key, value) in this)
				{
					serializer.SerializeMapEntry(key, value, first);
					first = false;
				}
				serializer.SerializeMapEnd();
			}

			public static Result<Self> Deserialize<D>(D deserializer)
				where D : IDeserializer
			{
				return deserializer.DeserializeMap<TKey, TValue>();
			}
		}

		extension List<T> : ISerializable
			where T : ISerializable
		{
			public void Serialize<S>(S serializer)
				where S : ISerializer
			{
				serializer.SerializeList(this);
			}

			public static Result<Self> Deserialize<D>(D deserializer)
				where D : IDeserializer
			{
				return deserializer.DeserializeList<T>();
			}
		}
	}
}